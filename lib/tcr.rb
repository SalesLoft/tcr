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
    TCR.cassette = Cassette.new(name)
    yield
    TCR.cassette.save
  ensure
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
    [:new, :open].each do |m|
      alias_method "real_#{m}", m

      define_method m do |*args|
        if TCR.configuration.hook_tcp_ports.include?(args[1])
          TCR::RecordableTCPSocket.new(TCR.cassette) do
            send("real_#{m}", *args)
          end
        else
          send("real_#{m}", *args)
        end
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
