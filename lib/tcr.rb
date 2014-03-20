require "tcr/cassette"
require "tcr/configuration"
require "tcr/errors"
require "tcr/socket_extension"
require "tcr/recordable"
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

  def disabled
    @disabled || false
  end

  def disabled=(v)
    @disabled = v
  end

  def save_session
  end

  def record_port?(port)
    configuration.hook_tcp_ports.include?(port)
  end

  def use_cassette(name, options = {}, &block)
    raise ArgumentError, "`TCR.use_cassette` requires a block." unless block
    TCR.cassette = Cassette.new(name)
    yield
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

TCPSocket.prepend(TCR::SocketExtension)
