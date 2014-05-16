require 'delegate'
require 'openssl'
require 'thread'


module TCR
  class RecordableTCPSocket
    attr_reader :live, :cassette, :socket
    attr_accessor :recording

    def initialize(address, port, cassette)
      raise TCR::NoCassetteError.new unless TCR.cassette

      @read_lock = Queue.new

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

    def gets(*args)
      if live
          data = @socket.gets(*args)
          recording << ["read", data]
      else
        _block_for_read_data if TCR.configuration.block_for_reads
        raise EOFError if recording.empty?
        direction, data = recording.shift
        raise TCR::DirectionMismatchError.new("Expected to 'read' but next in recording was '#{direction}'") unless direction == "read"
      end

      data
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

    def print(str)
      if live
        @socket.print(str)
        recording << ["write", str]
      else
        direction, data = recording.shift
        raise TCR::DirectionMismatchError.new("Expected to 'write' but next in recording was 'read'") unless direction == "write"
        _check_for_blocked_reads
      end
    end

    def write(str)
      if live
        len = @socket.write(str)
        recording << ["write", str]
      else
        direction, data = recording.shift
        raise TCR::DirectionMismatchError.new("Expected to 'write' but next in recording was 'read'") unless direction == "write"
        len = data.length
        _check_for_blocked_reads
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

    def _block_for_read_data
      while recording.first && recording.first.first != "read"
        @read_lock.pop
      end
    end

    def _check_for_blocked_reads
      @read_lock << 1
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

    def io
      self
    end

    def shutdown
      if live
        socket.io.shutdown
        cassette.append(recording)
      end
    end

    def connect
      self
    end

    def post_connection_check(*args)
      true
    end
  end
end
