# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
module SpawnTestServers
  # Spawn a new server that will send the specified payload when connected to.
  # The listening port number will be returned
  def spawn_server(payload)
    server = TCPServer.new("127.0.0.1", 0)
    fork do
      client = server.accept
      client.write(payload)
      client.close
    end
    server.addr[1]
  end
end

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.include(SpawnTestServers)
end
