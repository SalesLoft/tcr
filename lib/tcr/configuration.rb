module TCR
  class Configuration
    attr_accessor :cassette_library_dir, :hook_tcp_ports, :block_for_reads, :format, :hit_all

    def initialize
      reset_defaults!
    end

    def reset_defaults!
      @cassette_library_dir = "fixtures/tcr_cassettes"
      @hook_tcp_ports = []
      @block_for_reads = false
      @format = "json"
      @hit_all = false
    end
  end
end
