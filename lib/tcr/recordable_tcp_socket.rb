require 'delegate'
require 'openssl'
require 'thread'


module TCR
  class RecordableTCPSocket
    attr_reader :live, :socket, :recording

    def initialize(address, port, cassette)
      raise TCR::NoCassetteError.new unless TCR.cassette

      @read_lock = Queue.new
      @recording = cassette.next_session
      @live = cassette.recording?

      if live
        begin
          @socket = TCPSocket.real_open(address, port)
        rescue => e
          recording << ["error", Marshal.dump(e)]
          raise
        end
      else
        @closed = false
        check_recording_for_errors
      end
    end

    def read(*args)
      _read(:read, args)
    end

    def getc(*args)
      _read(:getc, args)
    end

    def gets(*args)
      _read(:gets, args)
    end

    def read_nonblock(*args)
      _read(:read_nonblock, args, blocking: false)
    end

    def print(str, *args)
      _write(:print, str, args)
    end

    def write(str, *args)
      _write(:write, str, args)
      str.length
    end

    def write_nonblock(str, *args)
      _write(:write_nonblock, str, args)
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
        @closed
      end
    end

    def close
      if live
        @socket.close
      else
        @closed = true
      end
    end

    def setsockopt(*args)
    end

    private

    def check_recording_for_errors
      raise Marshal.load(recording.first.last) if recording.first.first == "error"
    end

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

    def _write(method, data, args)
      if live
        payload = data.dup if !data.is_a?(Symbol)
        _delegate_call(method, args.unshift(payload))
        recording << ["write", data.dup]
      else
        direction, data = recording.shift
        _ensure_direction("write", direction)
        _check_for_blocked_reads
      end
    end

    def _read(method, args, opts = {})
      blocking = opts.fetch(:blocking, true)

      if live
          data    = _delegate_call(method, args)
          payload = data.dup if !data.is_a?(Symbol)
          recording << ["read", payload]
      else
        _block_for_read_data if blocking && TCR.configuration.block_for_reads
        raise EOFError if recording.empty?
        direction, data = recording.shift
        _ensure_direction("read", direction)
      end
      data
    end

    def _delegate_call(method, args)
      if RUBY_VERSION >= "2.7" && Hash === args.last
        kwargs = args.pop
        @socket.__send__(method, *args, **kwargs)
      else
        @socket.__send__(method, *args)
      end
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

    def ssl_version
      ""
    end

    def cipher
      []
    end

    def sync_close=(arg)
      true
    end

    def sync
      self
    end

    def sync=(arg)
      self
    end

    def flush
      self
    end

    def session
      self
    end

    def session=(args)
    end

    def hostname=(args)
    end

    def io
      self
    end

    def shutdown
      if live
        socket.io.shutdown
      end
    end

    def connect_nonblock(*)
      self
    end

    def connect
      self
    end

    def post_connection_check(*args)
      true
    end
  end
end
