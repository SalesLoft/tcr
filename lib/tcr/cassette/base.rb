module TCR
  module Cassette
    class Base
      attr_reader :name

      def initialize(name)
        @name = name

        if File.exist?(filename)
          @recording = false
          @sessions = deserialize
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
          @sessions << []
          @sessions.last
        else
          raise NoMoreSessionsError if @sessions.empty?
          @sessions.shift
        end
      end

      def save
        serialize(@sessions) if recording?
      end

      def filename
        File.join(TCR.configuration.cassette_library_dir, "#{name}.#{extension}")
      end
    end
  end
end
