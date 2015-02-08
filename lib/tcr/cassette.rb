module TCR
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name

      if File.exists?(filename)
        @recording = false
        @contents = File.open(filename) { |f| f.read }
        @sessions = parse
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
        File.open(filename, "w") { |f| f.write(dump) }
      end
    end

    def self.get_cassette(name, recording_format)
      if recording_format == :json
        JSONCassette.new(name)
      elsif recording_format == :yaml
        YAMLCassette.new(name)
      elsif recording_format == :bson
        BSONCassette.new(name)
      elsif recording_format == :msgpack
        MsgpackCassette.new(name)
      else
        raise TCR::FormatError.new
      end
    end
  end

  class JSONCassette < Cassette
    def parse
      JSON.parse(@contents)
    end

    def dump
      JSON.pretty_generate(@sessions)
    end

    protected

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.json"
    end
  end

  class YAMLCassette < Cassette
    def parse
      YAML.load(@contents)
    end

    def dump
      YAML.dump(@sessions)
    end

    protected

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.yaml"
    end
  end

  class BSONCassette < Cassette
    def parse
      Array.from_bson(StringIO.new(@contents))
    end

    def dump
      @sessions.to_bson
    end

    protected

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.bson"
    end
  end

  class MsgpackCassette < Cassette
    def parse
      MessagePack.unpack(@contents)
    end

    def dump
      @sessions.to_msgpack
    end

    protected

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.msgpack"
    end
  end
end
