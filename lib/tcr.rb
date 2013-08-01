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

  def current_cassette
    raise TCR::NoCassetteError unless @current_cassette
    @current_cassette
  end

  def use_cassette(name, options = {}, &block)
    raise ArgumentError, "`TCR.use_cassette` requires a block." unless block
    set_cassette(name)
    yield
    @current_cassette = nil
  end

  protected

  def set_cassette(name)
    @current_cassette = "#{TCR.configuration.cassette_library_dir}/#{name}.json"
  end
end


# The monkey patch shim
class TCPSocket
  class << self
    alias_method :real_open,  :open

    def open(address, port)
      if TCR.configuration.hook_tcp_ports.include?(port)
        TCR::RecordableTCPSocket.new(address, port, TCR.current_cassette)
      else
        real_open(address, port)
      end
    end
  end
end
