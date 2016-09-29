module TCR
  class Configuration
    attr_accessor :cassette_library_dir, :hook_tcp_ports, :block_for_reads, :serialize_with

    def initialize
      reset_defaults!
    end

    def reset_defaults!
      @cassette_library_dir = "fixtures/tcr_cassettes"
      @hook_tcp_ports = []
      @block_for_reads = false
      @serialize_with = :json
    end
  end
end
