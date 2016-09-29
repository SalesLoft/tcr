require "spec_helper"
require "tcr"
require "net/protocol"
require "net/http"
require "net/imap"
require "net/smtp"
require 'thread'
require "mail"


describe TCR do
  before(:each) do
    TCR.configuration.reset_defaults!
  end

  around(:each) do |example|
    File.unlink("test.json") if File.exists?("test.json")
    example.run
    File.unlink("test.json") if File.exists?("test.json")
  end

  describe ".configuration" do
     it "has a default cassette location configured" do
       TCR.configuration.cassette_library_dir.should == "fixtures/tcr_cassettes"
     end

     it "has an empty list of hook ports by default" do
       TCR.configuration.hook_tcp_ports.should == []
     end

     it "defaults to erroring on read/write mismatch access" do
       TCR.configuration.block_for_reads.should be_falsey
     end

     it "has a default cassette type" do
       TCR.configuration.serialize_with.should == :json
     end
  end

   describe ".configure" do
     it "configures cassette location" do
       expect {
         TCR.configure { |c| c.cassette_library_dir = "some/dir" }
       }.to change{ TCR.configuration.cassette_library_dir }.from("fixtures/tcr_cassettes").to("some/dir")
     end

     it "configures tcp ports to hook" do
       expect {
         TCR.configure { |c| c.hook_tcp_ports = [2525] }
       }.to change{ TCR.configuration.hook_tcp_ports }.from([]).to([2525])
     end

     it "configures allowing a blocking read mode" do
       expect {
         TCR.configure { |c| c.block_for_reads = true }
       }.to change{ TCR.configuration.block_for_reads }.from(false).to(true)
     end

     it "configures cassette type" do
       expect {
         TCR.configure { |c| c.serialize_with = :gzip }
       }.to change{ TCR.configuration.serialize_with }.from(:json).to(:gzip)
     end
   end

   it "raises an error if you connect to a hooked port without using a cassette" do
     TCR.configure { |c| c.hook_tcp_ports = [2525] }
     expect {
       tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
     }.to raise_error(TCR::NoCassetteError)
   end

  describe ".turned_off" do
    it "requires a block to call" do
      expect {
        TCR.turned_off
      }.to raise_error(ArgumentError)
    end

    it "disables hooks within the block" do
      TCR.configure { |c| c.hook_tcp_ports = [2525] }
      TCR.turned_off do
        TCR.configuration.hook_tcp_ports.should == []
      end
    end

    it "makes real TCPSocket.open calls even when hooks are setup" do
      TCR.configure { |c| c.hook_tcp_ports = [2525] }
      expect(TCPSocket).to receive(:real_open)
      TCR.turned_off do
        tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
      end
    end
  end

  describe "block_for_reads" do
    before(:each) {
      TCR.configure { |c|
        c.hook_tcp_ports = [9999]
        c.cassette_library_dir = '.'
      }
    }

    it "blocks read thread until data is available instead of raising mismatch error" do
      TCR.configure { |c| c.block_for_reads = true }
      reads = Queue.new

      TCR.use_cassette("spec/fixtures/block_for_reads") do
        sock = TCPSocket.open("google.com", 9999)

        t = Thread.new do
          reads << sock.gets
        end

        expect(reads.size).to eq(0)
        sock.print("hello\n")
        t.value
        expect(reads.size).to eq(1)
      end
    end

    context "when disabled" do
      it "raises mismatch error" do
        TCR.use_cassette("spec/fixtures/block_for_reads") do
          sock = TCPSocket.open("google.com", 9999)
          expect {
            Timeout::timeout(1) { sock.gets }
          }.to raise_error(TCR::DirectionMismatchError)
        end
      end
    end
  end

  describe ".use_cassette" do
    before(:each) {
      TCR.configure { |c|
        c.hook_tcp_ports = [2525]
        c.cassette_library_dir = "."
      }
    }

    it "requires a block to call" do
      expect {
        TCR.use_cassette("test")
      }.to raise_error(ArgumentError)
    end

    it "resets the cassette after use" do
      expect(TCR.cassette).to be_nil
      TCR.use_cassette("test") { }
      expect(TCR.cassette).to be_nil
    end

    it "resets the cassette after an error" do
      expect(TCR.cassette).to be_nil
      expect {
        TCR.use_cassette("test") { raise "Whoops!" }
      }.to raise_error("Whoops!")
      expect(TCR.cassette).to be_nil
    end

    it "creates a cassette file on use" do
      expect {
        TCR.use_cassette("test") do
          tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
        end
      }.to change{ File.exists?("./test.json") }.from(false).to(true)
    end

    it "records the tcp session data into the file" do
      TCR.use_cassette("test") do
        tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
        io = Net::InternetMessageIO.new(tcp_socket)
        line = io.readline
        tcp_socket.close
      end
      cassette_contents = File.open("test.json") { |f| f.read }
      cassette_contents.include?("220 smtp.mandrillapp.com ESMTP").should == true
    end

    it "plays back tcp sessions without opening a real connection" do
      expect(TCPSocket).to_not receive(:real_open)

      TCR.use_cassette("spec/fixtures/mandrill_smtp") do
        tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
        io = Net::InternetMessageIO.new(tcp_socket)
        line = io.readline.should include("220 smtp.mandrillapp.com ESMTP")
      end
    end

    it "raises an error if the recording gets out of order (i.e., we went to write but it expected a read)" do
      expect {
        TCR.use_cassette("spec/fixtures/mandrill_smtp") do
          tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          io.write("hi")
        end
      }.to raise_error(TCR::DirectionMismatchError)
    end

    it "stubs out Socket#gets" do
      TCR.configure { |c|
        c.hook_tcp_ports = [993]
        c.block_for_reads = true
      }
      expect {
        TCR.use_cassette("spec/fixtures/google_imap") do
          conn = Net::IMAP.new("imap.gmail.com", 993, true)
          conn.login("ben.olive@example.net", "password")
          conn.examine(Net::IMAP.encode_utf7("INBOX"))
          conn.disconnect
        end
      }.not_to raise_error
    end

    it "stubs out Socket#read" do
      TCR.configure { |c|
        c.hook_tcp_ports = [23]
      }
      TCR.use_cassette("spec/fixtures/starwars_telnet") do
        sock = TCPSocket.open("towel.blinkenlights.nl", 23)
        expect(sock.read(50).length).to eq(50)
        sock.close
      end
    end

    it "supports ssl sockets" do
      TCR.configure { |c| c.hook_tcp_ports = [443] }
      http = Net::HTTP.new("www.google.com", 443)
      http.use_ssl = true
      expect {
        TCR.use_cassette("spec/fixtures/google_https") do
          http.request(Net::HTTP::Get.new("/"))
        end
      }.not_to raise_error
    end

    it "supports gzip cassettes" do
      TCR.configure { |c|
        c.hook_tcp_ports = [80]
        c.serialize_with = :gzip
      }

      expect {
        TCR.use_cassette("spec/fixtures/google_http") do
          body = Net::HTTP.get(URI('http://google.com/'))
          expect(body.length).to eq(258)
        end
      }.not_to raise_error
    end

    it "can stub the full session of a real server accepting a real email over SMTPS with STARTTLS" do
      TCR.configure { |c|
        c.hook_tcp_ports = [587]
        c.block_for_reads = true
      }

      raw_contents = File.open("spec/fixtures/email_with_image.eml"){ |f| f.read }
      message = Mail::Message.new(raw_contents)
      smtp_auth_parameters = { address: "smtp.gmail.com", port: 587, user_name: "dummy", password: "dummy", enable_starttls_auto: true, authentication: :login}
      message.delivery_method(:smtp, smtp_auth_parameters)

      expect{
        TCR.use_cassette("spec/fixtures/smtp-success") do
          message.deliver
        end
      }.not_to raise_error
    end

    context "multiple connections" do
      it "records multiple sessions per cassette" do
        TCR.use_cassette("test") do
          smtp = Net::SMTP.start("smtp.mandrillapp.com", 2525)
          smtp.finish
          smtp = Net::SMTP.start("mail.smtp2go.com", 2525)
          smtp.finish
        end
        cassette_contents = File.open("test.json") { |f| f.read }
        cassette_contents.include?("smtp.mandrillapp.com ESMTP").should == true
        cassette_contents.include?("mail.smtp2go.com ESMTP").should == true
      end

      it "plays back multiple sessions per cassette in order" do
        TCR.use_cassette("spec/fixtures/multitest") do
          tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          line = io.readline.should include("smtp.mandrillapp.com ESMTP")

          tcp_socket = TCPSocket.open("mail.smtp2go.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          line = io.readline.should include("mail.smtp2go.com ESMTP")
        end
      end

      context "when a cassette is recorded with connections opens concurrently" do
        let(:ports) { ["Apple", "Banana"].map { |payload| spawn_server(payload) } }
        before(:each) do
          TCR.configure { |c|
            c.hook_tcp_ports = ports
            c.cassette_library_dir = "."
          }
        end
        before(:each) do
          TCR.use_cassette("test") do
            apple = TCPSocket.open("127.0.0.1", ports.first)
            banana = TCPSocket.open("127.0.0.1", ports.last)

            banana.gets
            apple.gets

            banana.close
            apple.close
          end
        end

        it "replays the sessions in the order they were created" do
          TCR.use_cassette("test") do
            apple = TCPSocket.open("127.0.0.1", ports.first)
            expect(apple.gets).to eq("Apple")
          end
        end
      end

      it "raises an error if you try to playback more sessions than you previously recorded" do
        expect {
          TCR.use_cassette("spec/fixtures/multitest-smtp") do
            smtp = Net::SMTP.start("smtp.mandrillapp.com", 2525)
            smtp = Net::SMTP.start("mail.smtp2go.com", 2525)
            smtp = Net::SMTP.start("mail.smtp2go.com", 2525)
          end
        }.to raise_error(TCR::NoMoreSessionsError)
      end
    end
  end
end
