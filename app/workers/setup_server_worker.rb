require 'sshkit/dsl'

class SetupServerWorker
	include Sidekiq::Worker
	sidekiq_options retry: 8
	sidekiq_retry_in do |count|
		4
	end

	def perform(user_id, droplet_id)
		user = User.find(user_id)
		droplet = Droplet.find(droplet_id)
		if droplet.minecraft_server.remote_setup_stage > 0
			return
		end
		host = SSHKit::Host.new(droplet.ip_address.to_s)
		host.user = 'root'
		host.key = Gamocosm.digital_ocean_ssh_private_key_path
		host.ssh_options = { passphrase: Gamocosm.digital_ocean_ssh_private_key_passphrase, user_known_hosts_file: '/dev/null', timeout: 4 }
		on host do
			within '/' do
				execute :adduser, '-m', 'mcuser'
				execute :echo, droplet.minecraft_server.name, '|', :passwd, '--stdin', 'mcuser'
				execute :usermod, '-aG', 'wheel', 'mcuser'
			end
		end
		droplet.minecraft_server.update_columns(remote_setup_stage: 1, pending_operation: nil)
	end
end
