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
