module TCR
  class Cassette
    attr_reader :name

    def self.build(name)
      if cassette_exists?(name)
        RecordedCassette.new(name)
      else
        RecordingCassette.new(name)
      end
    end

    def self.filename(name)
      "#{TCR.configuration.cassette_library_dir}/#{name}.json"
    end

    def self.cassette_exists?(name)
      File.exists?(filename(name))
    end

    def initialize(name)
      @name = name
    end

    protected

    def filename
      self.class.filename(name)
    end

    class RecordedCassette < Cassette
      def sessions
        @sessions ||= serialized_form
      end

      def recording?
        false
      end

      def next_session
        session = sessions.shift
        raise NoMoreSessionsError unless session
        Session.new(session, false)
      end

      def finish
        # no-op
      end

      private

      def serialized_form
        raw = File.open(filename) { |f| f.read }
        JSON.parse(raw)
      end
    end

    class RecordingCassette < Cassette
      def sessions
        @sessions ||= []
      end

      def recording?
        true
      end

      def next_session
        Session.new([], true).tap do |session|
          sessions << session
        end
      end

      def finish
        FileUtils.mkdir_p(File.dirname(filename))
        File.open(filename, "w") { |f| f.write(serialized_form) }
      end

      private

      def serialized_form
        JSON.pretty_generate(sessions.map(&:as_json))
      end
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
