require "spec_helper"
require "tcr"
require "net/protocol"
require "net/smtp"

describe TCR do
  before(:each) do
    TCR.configuration.reset_defaults!
  end

  describe ".configuration" do
     it "has a default cassette location configured" do
       TCR.configuration.cassette_library_dir.should == "fixtures/tcr_cassettes"
     end

     it "has an empty list of hook ports by default" do
       TCR.configuration.hook_tcp_ports.should == []
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
         TCR.configure { |c| c.hook_tcp_ports = [25] }
       }.to change{ TCR.configuration.hook_tcp_ports }.from([]).to([25])
     end
   end

  describe ".turned_off" do
    it "requires a block to call" do
      expect {
        TCR.turned_off
      }.to raise_error(ArgumentError)
    end

    it "makes real TCPSocket.open calls even when hooks are setup" do
      TCR.configure { |c| c.hook_tcp_ports = [25] }
      TCR.turned_off do
        tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
        expect(tcp_socket).not_to respond_to(:cassette)
      end
    end
  end

  describe ".use_cassette" do
    before(:each) {
      TCR.configure { |c|
        c.hook_tcp_ports = [25]
        c.cassette_library_dir = "."
      }
      File.unlink("test.json") if File.exists?("test.json")
    }
    after(:each) {
      File.unlink("test.json") if File.exists?("test.json")
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

    it "creates a cassette file on use" do
      expect {
        TCR.use_cassette("test") do
          tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
          tcp_socket.close
        end
      }.to change{ File.exists?("./test.json") }.from(false).to(true)
    end

    it "records the tcp session data into the file" do
      TCR.use_cassette("test") do
        tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
        io = Net::InternetMessageIO.new(tcp_socket)
        line = io.readline
        tcp_socket.close
      end
      cassette_contents = File.open("test.json") { |f| f.read }
      cassette_contents.include?("220 mx.google.com ESMTP").should == true
    end

    it "plays back tcp sessions without opening a real connection" do
      TCR.use_cassette("spec/fixtures/google_smtp") do
        tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
        expect(tcp_socket).to respond_to(:cassette)
        io = Net::InternetMessageIO.new(tcp_socket)
        line = io.readline.should include("220 mx.google.com ESMTP")
      end
    end

    it "raises an error if the recording gets out of order (i.e., we went to write but it expected a read)" do
      expect {
        TCR.use_cassette("spec/fixtures/google_smtp") do
          tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
          io = Net::InternetMessageIO.new(tcp_socket)
          io.write("hi")
        end
      }.to raise_error(TCR::CommandMismatchError)
    end


    context "multiple connections" do
      it "records multiple sessions per cassette" do
        TCR.use_cassette("test") do
          smtp = Net::SMTP.start("aspmx.l.google.com", 25)
          smtp.finish
          smtp = Net::SMTP.start("mta6.am0.yahoodns.net", 25)
          smtp.finish
        end
        cassette_contents = File.open("test.json") { |f| f.read }
        cassette_contents.include?("google.com ESMTP").should == true
        cassette_contents.include?("yahoo.com ESMTP").should == true
      end

      it "plays back multiple sessions per cassette in order" do
        TCR.use_cassette("spec/fixtures/multitest") do
          tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
          io = Net::InternetMessageIO.new(tcp_socket)
          line = io.readline.should include("google.com ESMTP")

          tcp_socket = TCPSocket.open("mta6.am0.yahoodns.net", 25)
          io = Net::InternetMessageIO.new(tcp_socket)
          line = io.readline.should include("yahoo.com ESMTP")
        end
      end

      it "raises an error if you try to playback more sessions than you previously recorded" do
        expect {
          TCR.use_cassette("spec/fixtures/multitest-smtp") do
            smtp = Net::SMTP.start("aspmx.l.google.com", 25)
            smtp = Net::SMTP.start("mta6.am0.yahoodns.net", 25)
            smtp = Net::SMTP.start("mta6.am0.yahoodns.net", 25)
          end
        }.to raise_error(TCR::NoMoreSessionsError)
      end
    end
  end
end
