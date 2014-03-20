module TCR
  module Recordable
    attr_reader :live
    attr_accessor :recording, :cassette

    def setup_recordable(cassette)
      @live = cassette.recording?
      @recording = cassette.next_session
      @cassette = cassette
    end

    def read_nonblock(bytes)
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
      end
    end
  end
end
