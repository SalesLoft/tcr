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

    class RecordingCassette < Cassette
      attr_reader :originally_recorded_at

      def initialize(*args)
        super
        @originally_recorded_at = Time.now
      end

      def sessions
        @sessions ||= []
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
        raw = {
          "originally_recorded_at" => originally_recorded_at,
          'sessions' => sessions.map(&:as_json)
        }
        JSON.pretty_generate(raw)
      end

      def empty?
        true
      end

      class Session
        def initialize
          @recording = []
        end

        def connect(&block)
          next_command('connect', ret: nil, &block)
        end

        def close(&block)
          next_command('close', &block)
        end

        def read(&block)
          next_command('read', &block)
        end

        def write(str, &block)
          next_command('write', data: str, &block)
        end

        def as_json
          {"recording" => @recording}
        end

        private

        def next_command(command, options={}, &block)
          yield.tap do |return_value|
            return_value = options[:ret] if options.has_key?(:ret)
            @recording << [command, return_value] + [options[:data]].compact
          end
        end
      end
    end

    class RecordedCassette < Cassette
      def sessions
        @sessions ||= serialized_form['sessions'].map{|raw| Session.new(raw)}
      end

      def originally_recorded_at
        serialized_form['originally_recorded_at']
      end

      def next_session
        session = sessions.shift
        raise NoMoreSessionsError unless session
        session
      end

      def finish
        # no-op
      end

      def empty?
        sessions.all?(&:empty?)
      end

      private

      def serialized_form
        @serialized_form ||= begin
          raw = File.open(filename) { |f| f.read }
          JSON.parse(raw)
        end
      end

      class Session
        def initialize(raw)
          @recording = raw["recording"]
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
          next_command('write') do |len, data|
            raise TCR::DataMismatchError.new("Expected to write '#{str}' but next data in recording was '#{data}'") unless str == data
          end
        end

        def empty?
          @recording.empty?
        end

        private

        def next_command(expected, expected_data=nil)
          command, return_value, data = @recording.shift
          raise TCR::CommandMismatchError.new("Expected to '#{expected}' but next in recording was '#{command}'") unless expected == command
          yield return_value, data if block_given?
          return_value
        end
      end
    end
  end
end
