require "tcr/cassette"
require "tcr/configuration"
require "tcr/errors"
require "tcr/recordable_tcp_socket"
require "tcr/version"
require "socket"
require "json"
require "yaml"


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

  def disabled
    @disabled || false
  end

  def disabled=(v)
    @disabled = v
  end

  def save_session
  end

  def use_cassette(name, options = {}, &block)
    raise ArgumentError, "`TCR.use_cassette` requires a block." unless block
    TCR.cassette = Cassette.get_cassette(name, configuration.recording_format)
    yield
    TCR.cassette.save
    TCR.cassette = nil
  end

  def turned_off(&block)
    raise ArgumentError, "`TCR.turned_off` requires a block." unless block
    current_hook_tcp_ports = configuration.hook_tcp_ports
    configuration.hook_tcp_ports = []
    yield
    configuration.hook_tcp_ports = current_hook_tcp_ports
  end
end


# The monkey patch shim
class TCPSocket
  class << self
    alias_method :real_open,  :open

    def open(address, port, *args)
      if TCR.configuration.hook_tcp_ports.include?(port)
        TCR::RecordableTCPSocket.new(address, port, TCR.cassette)
      else
        real_open(address, port)
      end
    end
  end
end

class OpenSSL::SSL::SSLSocket
  class << self
    def new(io, *args)
      if TCR::RecordableTCPSocket === io
        TCR::RecordableSSLSocket.new(io)
      else
        super
      end
    end
  end
end
