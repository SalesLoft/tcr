module TCR
  module Cassette
    class JSON < Base
      def initialize(_name)
        super
      end

      def extension
        :json
      end

      def serialize(data)
        File.binwrite(filename, ::JSON.pretty_generate(data))
      end

      def deserialize
        ::JSON.parse(File.binread(filename))
      end
    end
  end
end
