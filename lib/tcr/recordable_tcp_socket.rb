require 'delegate'
require 'openssl'


module TCR
  class RecordableTCPSocket
    attr_reader :live, :cassette
    attr_accessor :recording

    def initialize(address, port, cassette)
      raise TCR::NoCassetteError.new unless TCR.cassette

      if cassette.recording?
        @live = true
        @socket = TCPSocket.real_open(address, port)
        @recording = []
      else
        @live = false
        @recording = cassette.next_session
      end
      @cassette = cassette
    end

    def read_nonblock(bytes)
      if live
        data = @socket.read_nonblock(bytes)
        recording << ["read", data]
      else
        raise EOFError if recording.empty?
        direction, data = recording.shift
        raise TCR::DirectionMismatchError.new("Expected to 'read' but next in recording was 'write'") unless direction == "read"
      end

      data
    end

    def write(str)
      if live
        len = @socket.write(str)
        recording << ["write", str]
      else
        direction, data = recording.shift
        raise TCR::DirectionMismatchError.new("Expected to 'write' but next in recording was 'read'") unless direction == "write"
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
        cassette.append(recording)
      end
    end

    private

    def _intercept_socket
      if @socket
        @socket = yield @socket
      end
    end
  end

  class RecordableSSLSocket < SimpleDelegator
    def initialize(tcr_socket)
      super(tcr_socket)
      tcr_socket.send(:_intercept_socket) do |sock|
        socket = OpenSSL::SSL::SSLSocket.new(sock, OpenSSL::SSL::SSLContext.new)
        socket.sync_close = true
        socket.connect
        socket
      end
    end

    def sync_close=(arg)
      true
    end

    def session
      self
    end

    def session=(args)
    end

    def connect
      self
    end

    def post_connection_check(*args)
      true
    end
  end
end
