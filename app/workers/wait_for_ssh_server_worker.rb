require 'sshkit/dsl'
require 'timeout'

class WaitForSSHServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  sidekiq_retries_exhausted do |msg|
    args = msg['args']
    server = Server.find(args[1])
    server.minecraft.log("Background job waiting for ssh connection to server died: #{msg['error_message']}")
  end

  def perform(user_id, server_id, times = 0)
    server = Server.find(server_id)
    if !server.remote.exists?
      server.minecraft.log('Error starting server; remote_id is nil. Aborting')
      server.reset
      return
    end
    if server.remote.error?
      server.minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
      server.reset
      return
    end
    if times > 4
      server.minecraft.log('Error connecting to server; failed to SSH. Aborting')
      error = server.remote.destroy
      if error
        server.minecraft.log("Failed to destroy server after failing to connect; #{error}")
      end
      server.reset
      return
    end
    host = SSHKit::Host.new(server.remote.ip_address.to_s)
    host.user = 'root'
    host.key = Gamocosm.digital_ocean_ssh_private_key_path
    host.ssh_options = {
      passphrase: Gamocosm.digital_ocean_ssh_private_key_passphrase,
      paranoid: false,
      timeout: 16
    }
    begin
      Timeout::timeout(16) {
        on host do
          within '/tmp/' do
            execute :touch, 'test.txt'
          end
        end
      }
    rescue Timeout::Error, SSHKit::Runner::ExecuteError => e
      server.minecraft.log('Server started, but timed out while trying to SSH. Trying again in 16 seconds')
      WaitForSSHServerWorker.perform_in(16.seconds, user_id, server_id, times + 1)
      return
    end
    SetupServerWorker.perform_in(0.seconds, user_id, server_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server.minecraft.log("Background job waiting for SSH connection to server failed: #{e}")
    raise
  end
end

