module TCR
  module SSLSocketExtension
    def self.included(klass)
      klass.send(:alias_method, :initialize_without_tcr, :initialize)
      klass.send(:alias_method, :initialize, :initialize_with_tcr)
    end

    def initialize_with_tcr(s, context)
      initialize_without_tcr(s, context)
      if TCR.record_port?(s.remote_address.ip_port) && TCR.cassette
        extend(TCR::Recordable)
        self.cassette = TCR.cassette
      end
    end
  end
end
