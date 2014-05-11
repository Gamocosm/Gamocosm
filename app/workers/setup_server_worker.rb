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
			within '/opt/' do
				if test '! id -u mcuser'
					execute :adduser, '-m', 'mcuser'
				end
				execute :echo, droplet.minecraft_server.name, '|', :passwd, '--stdin', 'mcuser'
				execute :usermod, '-aG', 'wheel', 'mcuser'
				execute :yum, '-y', 'update'
				execute :yum, '-y', 'install', 'java-1.7.0-openjdk-headless', 'python3', 'python3-devel', 'python3-pip', 'supervisor', 'proftpd'
				execute 'python3-pip', 'install', 'flask'
				if test '! iptables -nL | grep -q 5000'
					execute :iptables, '-I', 'INPUT', '-p', 'tcp', '--dport', '5000', '-j', 'ACCEPT'
					execute 'iptables-save'
				end
				execute :mkdir, '-p', 'gamocosm'
				within :gamocosm do
					execute :rm, '-f', 'minecraft-flask.py'
					execute :wget, '-O', 'minecraft-flask.py', 'https://raw.github.com/Raekye/minecraft-server_wrapper/master/minecraft-flask-minified.py'
					execute :echo, "\"#{Gamocosm.minecraft_wrapper_username}\"", '>', 'minecraft-flask-auth.txt'
					execute :echo, "\"#{droplet.minecraft_server.minecraft_wrapper_password}\"", '>>', 'minecraft-flask-auth.txt'
				end
			end
			within '/home/mcuser/' do
				execute :mkdir, '-p', 'minecraft'
				execute :chown, 'mcuser:mcuser', 'minecraft'
				within :minecraft do
					execute :rm, '-f', 'minecraft_server-run.jar'
					execute :wget, '-O', 'minecraft_server-run.jar', Gamocosm.minecraft_jar_default_url
					execute :chown, 'mcuser:mcuser', 'minecraft'
				end
			end
			within '/etc/supervisord.d/' do
				execute :rm, '-f', 'minecraft_wrapper.ini'
				execute :wget, '-O', 'minecraft_wrapper.ini', 'https://raw.github.com/Raekye/minecraft-server_wrapper/master/supervisor.conf'
				execute :systemctl, 'start', 'supervisord'
				execute :systemctl, 'enable', 'supervisord'
				execute :supervisorctl, 'reread'
				execute :supervisorctl, 'update'
			end
		end
		droplet.minecraft_server.resume
		droplet.minecraft_server.update_columns(remote_setup_stage: 1, pending_operation: nil)
	end
end
