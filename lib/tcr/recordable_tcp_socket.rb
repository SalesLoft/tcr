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

    def read(bytes)
      _read(:read, bytes)
    end

    def gets(*args)
      _read(:gets, *args)
    end

    def read_nonblock(bytes)
      _read(:read_nonblock, bytes, blocking: false)
    end

    def print(str)
      _write(:print, str)
    end

    def write(str)
      _write(:write, str)
      str.length
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

    def setsockopt(*args)
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

    def _write(method, data)
      if live
        @socket.__send__(method, data)
        recording << ["write", data]
      else
        direction, data = recording.shift
        _ensure_direction("write", direction)
        _check_for_blocked_reads
      end
    end

    def _read(method, *args, blocking: true)
      if live
          data = @socket.__send__(method, *args)
          recording << ["read", data]
      else
        _block_for_read_data if blocking && TCR.configuration.block_for_reads
        raise EOFError if recording.empty?
        direction, data = recording.shift
        _ensure_direction("read", direction)
      end
      data
    end

    def _ensure_direction(desired, actual)
      raise TCR::DirectionMismatchError.new("Expected to '#{desired}' but next in recording was '#{actual}'") unless desired == actual
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
