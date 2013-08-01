require "spec_helper"
require "tcr"
require "net/protocol"

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

   describe ".confige" do
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

   it "raises an error if you connect to a hooked port without using a cassette" do
     TCR.configure { |c| c.hook_tcp_ports = [25] }
     expect {
       tcp_socket = TCPSocket.open("aspmx.l.google.com", 25)
     }.to raise_error(TCR::NoCassetteError)
   end

  describe ".use_cassette" do
    before(:each) {
      TCR.configure { |c|
        c.hook_tcp_ports = [25]
        c.cassette_library_dir = "."
      }
      File.unlink("./test.json") if File.exists?("./test.json")
    }
    after(:each) {
      File.unlink("./test.json") if File.exists?("./test.json")
    }

    it "requires a block to call" do
      expect {
        TCR.use_cassette("test")
      }.to raise_error(ArgumentError)
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
      file_contents = File.open("./test.json") { |f| f.read }
      file_contents.include?("220 mx.google.com ESMTP").should == true
    end
  end
end