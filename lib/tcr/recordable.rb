module TCR
  module Recordable
    attr_accessor :cassette

    def recording
      @recording ||= cassette.next_session
    end

    def connect
      recording.connect do
        super
      end
    end

    def read_nonblock(bytes)
      recording.read do
        super
      end
    end

    def gets(*args)
      recording.read do
        super
      end
    end

    def write(str)
      recording.write(str) do
        super
      end
    end

    def to_io
      if cassette.recording?
        super
      end
    end

    def close
      recording.close do
        super
      end
    end
  end
end
