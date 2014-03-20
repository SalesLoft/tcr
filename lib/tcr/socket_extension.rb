module TCR
  module SocketExtension
    def initialize(address, port, *args)
      super
      if TCR.record_port?(port) && TCR.cassette
        extend(Recordable)
        setup_recordable(TCR.cassette)
      end
    end
  end
end
