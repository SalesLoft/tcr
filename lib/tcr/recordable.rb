module TCR
  module Recordable
    attr_reader :live
    attr_accessor :recording, :cassette

    def setup_recordable(cassette)
      if cassette.recording?
        @live = true
        @recording = []
      else
        @live = false
        @recording = cassette.next_session
      end
      @cassette = cassette
    end

    def read_nonblock(bytes)
      if live
        data = super
        recording << ["read", data]
      else
        direction, data = recording.shift
        raise TCR::DirectionMismatchError.new("Expected to 'read' but next in recording was 'write'") unless direction == "read"
      end

      data
    end

    def write(str)
      if live
        len = super
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
        super
      end
    end

    def closed?
      if live
        super
      else
        false
      end
    end

    def close
      if live
        super
        cassette.append(recording)
      end
    end
  end
end
