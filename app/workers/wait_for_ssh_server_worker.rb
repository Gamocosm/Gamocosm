require 'sshkit/dsl'
require 'timeout'

class WaitForSSHServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(user_id, droplet_id, times = 0)
    droplet = Droplet.find(droplet_id)
    if times > 8
      logger.warn "WaitForSSHServerWorker#perform: cannot ssh into droplet, user #{user_id}, droplet #{droplet_id}"
      droplet.minecraft_server.destroy_remote
      droplet.minecraft_server.update_columns(pending_operation: nil)
      return
    end
    if !droplet.remote.exists?
      logger.info "Droplet #{droplet_id} in #{self.class} remote doesn't exist (remote_id nil)"
      return
    end
    host = SSHKit::Host.new(droplet.ip_address.to_s)
    host.user = 'root'
    host.key = Gamocosm.digital_ocean_ssh_private_key_path
    host.ssh_options = {
      passphrase: Gamocosm.digital_ocean_ssh_private_key_passphrase,
      paranoid: false,
      timeout: 4
    }
    begin
      on host do
        within '/tmp/' do
          execute :touch, 'test.txt'
        end
      end
    rescue Timeout::Error => e
      WaitForSSHServerWorker.perform_in(16.seconds, user_id, droplet_id, times + 1)
      return
    end
    SetupServerWorker.perform_in(0.seconds, user_id, droplet_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end

