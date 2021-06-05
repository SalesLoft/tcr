require "spec_helper"
require "tcr"
require "net/protocol"
require "net/http"
require "net/imap"
require "net/smtp"
require "net/ldap"
require "tcr/net/ldap"
require "mail"


RSpec.describe TCR do
  before(:each) do
    TCR.configuration.reset_defaults!
  end

  around(:each) do |example|
    File.unlink("test.json") if File.exists?("test.json")
    File.unlink("test.yaml") if File.exists?("test.yaml")
    File.unlink("test.marshal") if File.exists?("test.marshal")
    example.run
    File.unlink("test.json") if File.exists?("test.json")
    File.unlink("test.yaml") if File.exists?("test.yaml")
    File.unlink("test.marshal") if File.exists?("test.marshal")
  end

  describe ".configuration" do
    it "has a default cassette location configured" do
      expect(TCR.configuration.cassette_library_dir).to eq "fixtures/tcr_cassettes"
    end

    it "has an empty list of hook ports by default" do
      expect(TCR.configuration.hook_tcp_ports).to eq []
    end

    it "defaults to erroring on read/write mismatch access" do
      expect(TCR.configuration.block_for_reads).to be_falsey
    end

    it "defaults to hit all to false" do
      expect(TCR.configuration.hit_all).to be_falsey
    end
  end

  describe ".configure" do
    context "with cassette_library_dir option" do
      it "configures cassette location" do
        expect {
          TCR.configure { |c| c.cassette_library_dir = "some/dir" }
        }.to change{ TCR.configuration.cassette_library_dir }.from("fixtures/tcr_cassettes").to("some/dir")
      end
    end

    context "with hook_tcp_ports option" do
      it "configures tcp ports to hook" do
        expect {
          TCR.configure { |c| c.hook_tcp_ports = [2525] }
        }.to change{ TCR.configuration.hook_tcp_ports }.from([]).to([2525])
      end
    end

    context "with block_for_reads option" do
      before(:each) {
        TCR.configure { |c|
          c.hook_tcp_ports = [9999]
          c.cassette_library_dir = '.'
        }
      }

      it "configures allowing a blocking read mode" do
        expect {
          TCR.configure { |c| c.block_for_reads = true }
        }.to change{ TCR.configuration.block_for_reads }.from(false).to(true)
      end

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

    context "with hit_all option" do
      it "configures to check if all sessions were hit" do
        expect {
          TCR.configure { |c| c.hit_all = true }
        }.to change{ TCR.configuration.hit_all }.from(false).to(true)
      end
    end
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
        expect(TCR.configuration.hook_tcp_ports).to eq []
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

  describe ".use_cassette" do
    before(:each) {
      TCR.configure { |c|
        c.hook_tcp_ports = [2525]
        c.cassette_library_dir = "."
      }
    }

    it "MUST be used when connecting to hooked ports (or else raises an error)" do
      TCR.configure { |c| c.hook_tcp_ports = [2525] }
      expect {
        tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
      }.to raise_error(TCR::NoCassetteError)
    end

    it "requires a block to call" do
      expect {
        TCR.use_cassette("test")
      }.to raise_error(ArgumentError)
    end

    context "when path to cassette does not exist" do
      let(:unique_dirname) { Dir.entries(".").sort.last.next }

      around do |example|
        expect(Dir.exist?(unique_dirname)).to be(false)
        example.run
        FileUtils.rm_rf(unique_dirname)
      end

      it "creates it" do
        expect { TCR.use_cassette("#{unique_dirname}/foo/bar/test") { } }.not_to raise_error
      end
    end

    context "when path to cassette is not writable" do
      let(:unique_dirname) { Dir.entries(".").sort.last.next }

      around do |example|
        FileUtils.mkdir(unique_dirname)
        FileUtils.chmod("u-w", unique_dirname)
        expect { FileUtils.touch("#{unique_dirname}/foo") }.to raise_error(Errno::EACCES)
        example.run
        FileUtils.rm_rf(unique_dirname)
      end

      it "raises error BEFORE block runs" do
        allow(TCPSocket).to receive(:open)

        expect do
          TCR.use_cassette("#{unique_dirname}/foo") do
            TCPSocket.open("smtp.mandrillapp.com", 2525)
          end
        end.to raise_error(Errno::EACCES)

        expect(TCPSocket).not_to have_received(:open)
      end
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

    context "when configured for JSON format" do
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
        expect(cassette_contents.include?("220 smtp.mandrillapp.com ESMTP")).to be_truthy
      end
    end

    context "when configured for YAML format" do
      before { TCR.configure { |c| c.format = "yaml" } }

      it "creates a cassette file on use with yaml" do
        expect {
          TCR.use_cassette("test") do
            tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          end
        }.to change{ File.exists?("./test.yaml") }.from(false).to(true)
      end

      it "records the tcp session data into the yaml file" do
        TCR.use_cassette("test") do
          tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          line = io.readline
          tcp_socket.close
        end
        cassette_contents = File.open("test.yaml") { |f| f.read }
        expect(cassette_contents.include?("---")).to be_truthy
        expect(cassette_contents.include?("220 smtp.mandrillapp.com ESMTP")).to be_truthy
      end
    end

    context "when configured for Marshal format" do
      before { TCR.configure { |c| c.format = "marshal" } }

      it "creates a cassette file on use with marshal" do
        expect {
          TCR.use_cassette("test") do
            tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          end
        }.to change{ File.exists?("./test.marshal") }.from(false).to(true)
      end

      it "records the tcp session data into the marshalled file" do
        TCR.use_cassette("test") do
          tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          line = io.readline
          tcp_socket.close
        end
        unmarshalled_cassette = Marshal.load(File.read("test.marshal"))
        expect(unmarshalled_cassette).to be_a(Array)
        expect(unmarshalled_cassette.first.last.last).to eq("220 smtp.mandrillapp.com ESMTP\r\n")
      end

      context "when Encoding.default_internal == Encoding::UTF_8 (as in Rails)" do
        before { Encoding.default_internal = Encoding::UTF_8 }
        let(:invalid_unicode_string) { "\u0001\u0001\u0004€" }

        it "doesn't fail on cassettes with binary content" do
          expect do
            TCR.use_cassette("test") do
              TCR.cassette.instance_variable_get(:@sessions) << ["read", invalid_unicode_string]
            end
          end.not_to raise_error
        end
      end
    end

    it "plays back tcp sessions without opening a real connection" do
      expect(TCPSocket).to_not receive(:real_open)

      TCR.use_cassette("spec/fixtures/mandrill_smtp") do
        tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
        io = Net::InternetMessageIO.new(tcp_socket)
        expect(io.readline).to include("220 smtp.mandrillapp.com ESMTP")
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
        expect(cassette_contents.include?("smtp.mandrillapp.com ESMTP")).to be_truthy
        expect(cassette_contents.include?("mail.smtp2go.com ESMTP")).to be_truthy
      end

      it "plays back multiple sessions per cassette in order" do
        TCR.use_cassette("spec/fixtures/multitest") do
          tcp_socket = TCPSocket.open("smtp.mandrillapp.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          expect(io.readline).to include("smtp.mandrillapp.com ESMTP")

          tcp_socket = TCPSocket.open("mail.smtp2go.com", 2525)
          io = Net::InternetMessageIO.new(tcp_socket)
          expect(io.readline).to include("mail.smtp2go.com ESMTP")
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

      it "raises an error if you try to playback less sessions than you previously recorded" do
        expect {
          TCR.use_cassette("spec/fixtures/multitest-extra-smtp", hit_all: true) do
            smtp = Net::SMTP.start("smtp.mandrillapp.com", 2525)
          end
        }.to raise_error(TCR::ExtraSessionsError)
      end
    end
  end

  context "when TCPSocket.open raises an error during recording" do
    before do
      TCR.configure { |c|
        c.format = "yaml" # JSON borks on binary strings
        c.hook_tcp_ports = [143]
        c.cassette_library_dir = "."
      }

      # record cassette
      TCR.use_cassette("test") do
        expect { Net::IMAP.new(nil) }.to raise_error(SystemCallError)
      end
    end

    it "records error to cassette" do
      expect(File.exist?('test.yaml')).to be(true)
      expect(File.read('test.yaml')).not_to be_empty
    end

    it "re-raises the error during replay" do
      TCR.use_cassette("test") do
        expect { Net::IMAP.new(nil) }.to raise_error(SystemCallError)
      end
    end
  end

  it "replaces sockets created with Socket.tcp" do
    TCR.configure { |c|
      c.hook_tcp_ports = [23]
      c.cassette_library_dir = "."
    }

    TCR.use_cassette("spec/fixtures/starwars_telnet") do
      sock = Socket.tcp("towel.blinkenlights.nl", 23)
      expect(sock).to be_a(TCR::RecordableTCPSocket)
    end
  end

  it "handles frozen Strings" do
    TCR.configure { |c|
      c.hook_tcp_ports = [443]
      c.cassette_library_dir = "."
    }

    TCR.use_cassette("test") do
      sock = TCPSocket.open("google.com", 443)
      sock.print("hello\n".freeze)
    end
  end

  it "supports Net::LDAP connections" do
    TCR.configure { |c|
      c.hook_tcp_ports       = [389]
      c.format               = 'marshal'
      c.cassette_library_dir = "."
    }
    expect {
      TCR.use_cassette("spec/fixtures/ldap") do
        ldap = Net::LDAP.new(
          host: 'ldap.forumsys.com',
          port: 389,
        )

        ldap.auth 'cn=read-only-admin,dc=example,dc=com', 'password'

        ldap.search(
          base:          'DC=example,DC=com',
          filter:        '(ou=mathematicians,dc=example,dc=com)',
          scope:         Net::LDAP::SearchScope_WholeSubtree,
          return_result: false
        ) do |_entry|
          break
        end
      end
    }.not_to raise_error
  end

  context 'Ractor' do
    before do
      TCR.configure { |c|
        c.hook_tcp_ports = [23]
        c.cassette_library_dir = "."
      }
    end

    it 'should be available in Ractors' do
      next unless defined?(Ractor)

      TCR.use_cassette("spec/fixtures/starwars_telnet") do
        sock = Socket.tcp("towel.blinkenlights.nl", 23)
        expect do
          Ractor.new(sock) do |sock|
            #noop
          end
        end.not_to raise_error
      end
    end
  end
end
