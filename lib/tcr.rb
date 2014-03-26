require "tcr/cassette"
require "tcr/configuration"
require "tcr/errors"
require "tcr/socket_extension"
require "tcr/recordable"
require "tcr/version"
require "socket"
require "json"

module TCR
  ALL_PORTS = '*'
  SOCKET_CLASSES = [TCPSocket, OpenSSL::SSL::SSLSocket]

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

  def record_port?(port)
    !disabled && configuration.hook_tcp_ports == ALL_PORTS || configuration.hook_tcp_ports.include?(port)
  end

  def use_cassette(name, options = {}, &block)
    raise ArgumentError, "`TCR.use_cassette` requires a block." unless block
    begin
      TCR.cassette = Cassette.build(name)
      yield TCR.cassette
    ensure
      TCR.cassette.finish
      TCR.cassette = nil
    end
  end

  def turned_off(&block)
    raise ArgumentError, "`TCR.turned_off` requires a block." unless block
    begin
      disabled = true
      yield
    ensure
      disabled = false
    end
  end
end

TCR::SOCKET_CLASSES.each{|klass|klass.prepend(TCR::SocketExtension)}
