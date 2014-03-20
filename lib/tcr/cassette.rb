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
        Session.new(session)
      end

      def finish
        # no-op
      end

      private

      def serialized_form
        raw = File.open(filename) { |f| f.read }
        JSON.parse(raw)
      end

      class Session
        def initialize(recording)
          @recording = recording
        end

        def connect
          next_command('connect')
        end

        def close
          next_command('close')
        end

        def read
          next_command('read')
        end

        def write(str)
          data = next_command('write') do |data|
            raise TCR::DataMismatchError.new("Expected to write '#{str}' but next data in recording was '#{data}'") unless str == data
          end
          data.length
        end

        private

        def next_command(expected, expected_data=nil)
          actual, data = @recording.shift
          raise TCR::CommandMismatchError.new("Expected to '#{expected}' but next in recording was '#{actual}'") unless expected == actual
          yield data if block_given?
          data
        end
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
        Session.new.tap do |session|
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

      class Session
        def initialize
          @recording = []
        end

        def connect
          yield.tap do |success|
            @recording << ["connect", success]
          end
        end

        def close
          yield.tap do |success|
            @recording << ["close", success]
          end
        end

        def read
          yield.tap do |data|
            @recording << ["read", data]
          end
        end

        def write(str)
          yield.tap do |len|
            @recording << ["write", str]
          end
        end

        def as_json
          @recording
        end
      end
    end
  end
end
