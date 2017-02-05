module TCR
  module Cassette
    def self.build(name, type)
      case type
      when :gzip
        TCR::Cassette::Gzip.new(name)
      else
        TCR::Cassette::JSON.new(name)
      end
    end
  end
end

require "tcr/cassette/base"
require "tcr/cassette/json"
require "tcr/cassette/gzip"
