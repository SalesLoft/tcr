module TCR
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name

      if File.exists?(filename)
        @recording = false
        @contents = File.open(filename) { |f| f.read }
        @sessions = JSON.parse(@contents)
      else
        @recording = true
        @sessions = []
      end
    end

    def recording?
      @recording
    end

    def next_session
      if recording?
        Session.new([], true)
      else
        session = @sessions.shift
        raise NoMoreSessionsError unless session
        Session.new(session, false)
      end
    end

    def append(session)
      raise "Can't append session unless recording" unless recording?
      @sessions << session.as_json
      File.open(filename, "w") { |f| f.write(JSON.pretty_generate(@sessions)) }
    end

    protected

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
