require "tcr/version"
require "socket"
require "json"

module TCR
  extend self

  def configure
    yield configuration
  end

  def configuration
    @configuration ||= Configuration.new
  end

  def current_cassette
    @current_cassette
  end

  def use_cassette(name, options = {}, &block)
    raise ArgumentError, "`TCR.use_cassette` requires a block." unless block
    set_cassette(name)
    yield
    @current_cassette = nil
  end

  protected

  def set_cassette(name)
    @current_cassette = "#{TCR.configuration.cassette_library_dir}/#{name}.json"
  end
end


module TCR
  class Configuration
    attr_accessor :cassette_library_dir, :hook_tcp_ports

    def initialize
      reset_defaults!
    end

    def reset_defaults!
      @cassette_library_dir = "fixtures/tcr_cassettes"
      @hook_tcp_ports = []
    end
  end
end


module TCR
  class TCRError < StandardError; end
  class NoCassetteError < TCRError; end
  class DirectionMismatchError < TCRError; end
end


module TCR
  class RecordableTCPSocket
    attr_reader :live, :recording_file
    attr_accessor :recordings

    def initialize(address, port, recording_file)
      @recording_file = recording_file

      if File.exists?(recording_file)
        @live = false
        @recordings = JSON.parse(File.open(recording_file, "r") { |f| f.read })
      else
        @live = true
        @recordings = []
        @socket = TCPSocket.real_open(address, port)
      end
    end

    def read_nonblock(bytes)
      if live
        data = @socket.read_nonblock(bytes)
        recordings << ["read", data]
      else
        direction, data = recordings.shift
        raise DirectionMismatchError("Expected to 'read' but next in recording was 'write'") unless direction == "read"
      end

      data
    end

    def write(str)
      if live
        len = @socket.write(str)
        recordings << ["write", str]
      else
        direction, data = recordings.shift
        raise DirectionMismatchError("Expected to 'write' but next in recording was 'read'") unless direction == "write"
        len = data.length
      end

      len
    end

    def to_io
      if live
        @socket.to_io
      end
    end

    def closed?
      if live
        @socket.closed?
      else
        false
      end
    end

    def close
      if live
        @socket.close
        File.open(recording_file, "w") { |f| f.write(JSON.pretty_generate(recordings)) }
      end
    end
  end
end


# The shim
class TCPSocket
  class << self
    alias_method :real_open,  :open

    def open(address, port)
      if TCR.configuration.hook_tcp_ports.include?(port)
        if TCR.current_cassette
          TCR::RecordableTCPSocket.new(address, port, TCR.current_cassette)
        else
          raise TCR::NoCassetteError
        end
      else
        real_open(address, port)
      end
    end
  end
end

