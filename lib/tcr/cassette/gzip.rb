module TCR
  module Cassette
    class Gzip < Base
      def initialize(_name)
        super
      end

      def extension
        :gz
      end

      def serialize(data)
        Zlib::GzipWriter.open(filename) do |gz|
          gz.write(Marshal.dump(data))
        end
      end

      def deserialize
        Zlib::GzipReader.open(filename) do |gz|
          return Marshal.load(gz.read)
        end
      end
    end
  end
end
