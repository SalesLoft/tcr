module TCR
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name
      @recording = !File.exists?(filename)
    end

    def sessions
      @sessions ||= if recording?
        []
      else
        read_serialized_form
      end
    end

    def recording?
      @recording
    end

    def next_session
      if recording?
        Session.new([], true).tap do |session|
          sessions << session
        end
      else
        session = sessions.shift
        raise NoMoreSessionsError unless session
        Session.new(session, false)
      end
    end

    def finish
      if recording?
        FileUtils.mkdir_p(File.dirname(filename))
        File.open(filename, "w") { |f| f.write(serialized_form) }
      end
    end

    protected

    def read_serialized_form
      raw = File.open(filename) { |f| f.read }
      JSON.parse(raw)
    end

    def serialized_form
      JSON.pretty_generate(sessions.map(&:as_json))
    end

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.json"
    end

    class Session
      def initialize(recording, live)
        @live = live
        @recording = recording
      end

      def live
        @live
      end

      def gets
        yield
      end

      def connect
        yield
      end

      def close
        yield
      end

      def read
        if live
          data = yield
          @recording << ["read", data]
        else
          direction, data = @recording.shift
          raise TCR::DirectionMismatchError.new("Expected to 'read' but next in recording was 'write'") unless direction == "read"
        end

        data
      end

      def write(str)
        if live
          len = yield
          @recording << ["write", str]
        else
          direction, data = @recording.shift
          raise TCR::DirectionMismatchError.new("Expected to 'write' but next in recording was 'read'") unless direction == "write"
          len = data.length
        end

        len
      end

      def as_json
        @recording
      end
    end
  end
end
