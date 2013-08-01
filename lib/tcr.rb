require "tcr/cassette"
require "tcr/configuration"
require "tcr/errors"
require "tcr/recordable_tcp_socket"
require "tcr/version"
require "socket"
require "json"


module TCR
  extend self

  def configure
    yield configuration
  end

  def configuration
    @configuration ||= Configuration.new
  end

  def cassette
    @cassette
  end

  def cassette=(v)
    @cassette = v
  end

  def save_session
  end

  def use_cassette(name, options = {}, &block)
    raise ArgumentError, "`TCR.use_cassette` requires a block." unless block
    TCR.cassette = Cassette.new(name)
    yield
    @current_cassette = nil
  end
end


# The monkey patch shim
class TCPSocket
  class << self
    alias_method :real_open,  :open

    def open(address, port)
      if TCR.configuration.hook_tcp_ports.include?(port)
        TCR::RecordableTCPSocket.new(address, port, TCR.cassette)
      else
        real_open(address, port)
      end
    end
  end
end
