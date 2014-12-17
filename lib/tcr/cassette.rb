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
        @sessions << []
        @sessions.last
      else
        raise NoMoreSessionsError if @sessions.empty?
        @sessions.shift
      end
    end

    def save
      if recording?
        File.open(filename, "w") { |f| f.write(JSON.pretty_generate(@sessions)) }
      end
    end

    protected

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.json"
    end
  end
end
