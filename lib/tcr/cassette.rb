require 'fileutils'

module TCR
  class Cassette
    attr_reader :name

    def initialize(name)
      @name = name

      if recording?
        verify_cassette_path_is_writable
        @sessions = []
      else
        @sessions = unmarshal(File.read(filename))
      end
    end

    def recording?
      @recording ||= !File.exist?(filename)
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
      return if !recording?
      File.write(filename, marshal(@sessions))
    rescue Encoding::UndefinedConversionError
      File.binwrite(filename, marshal(@sessions))
    end

    def check_hits_all_sessions
      if !recording?
        raise ExtraSessionsError if !@sessions.empty?
      end
    end

    protected

    def unmarshal(content)
      case TCR.configuration.format
      when "json"
        JSON.parse(content)
      when "yaml"
        YAML.load(content)
      when "marshal"
        Marshal.load(content)
      else
        raise "unrecognized cassette format '#{TCR.configuration.format}'; " \
              "please use one of 'json', 'yaml', or 'marshal'"
      end
    end

    def marshal(content)
      case TCR.configuration.format
      when "json"
        JSON.pretty_generate(content)
      when "yaml"
        YAML.dump(content)
      when "marshal"
        Marshal.dump(content)
      else
        raise "unrecognized cassette format '#{TCR.configuration.format}'; " \
              "please use one of 'json', 'yaml', or 'marshal'"
      end
    end

    def filename
      "#{TCR.configuration.cassette_library_dir}/#{name}.#{TCR.configuration.format}"
    end

    def verify_cassette_path_is_writable
      FileUtils.mkdir_p(File.dirname(filename))
      FileUtils.touch(filename)
    end
  end
end
