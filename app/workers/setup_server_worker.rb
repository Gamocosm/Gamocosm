require 'sshkit/dsl'

class SetupServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(user_id, server_id)
    user = User.find(user_id)
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
    host = SSHKit::Host.new(server.remote.ip_address.to_s)
    host.user = 'root'
    host.key = Gamocosm.digital_ocean_ssh_private_key_path
    host.ssh_options = {
      passphrase: Gamocosm.digital_ocean_ssh_private_key_passphrase,
      paranoid: false,
      timeout: 4
    }
    if !server.done_setup?
      on host do
        within '/tmp/' do
          server.update_columns(remote_setup_stage: 1)
          if test '! id -u mcuser'
            execute :adduser, '-m', 'mcuser'
          end
          execute :echo, server.minecraft.name, '|', :passwd, '--stdin', 'mcuser'
          execute :usermod, '-aG', 'wheel', 'mcuser'
          server.update_columns(remote_setup_stage: 2)
          execute :yum, '-y', 'update'
          execute :yum, '-y', 'install', 'java-1.7.0-openjdk-headless', 'python3', 'python3-devel', 'python3-pip', 'supervisor', 'tmux', 'iptables-services'
          execute :rm, '-rf', 'pip_build_root'
          execute 'python3-pip', 'install', 'flask'
        end
        within '/opt/' do
          execute :mkdir, '-p', 'gamocosm'
          if test '! grep -q gamocosm /etc/group'
            execute :groupadd, 'gamocosm'
          end
          execute :chgrp, 'gamocosm', 'gamocosm'
          execute :usermod, '-aG', 'gamocosm', 'mcuser'
          execute :chmod, 'g+w', 'gamocosm'
          within :gamocosm do
            execute :rm, '-f', 'minecraft-flask.py'
            execute :wget, '-O', 'minecraft-flask.py', 'https://raw.github.com/Raekye/minecraft-server_wrapper/master/minecraft-flask-minified.py'
            execute :chown, 'mcuser:mcuser', 'minecraft-flask.py'
            execute :echo, "\"#{Gamocosm.minecraft_wrapper_username}\"", '>', 'minecraft-flask-auth.txt'
            execute :echo, "\"#{server.minecraft.minecraft_wrapper_password}\"", '>>', 'minecraft-flask-auth.txt'
          end
        end
        server.update_columns(remote_setup_stage: 3)
        within '/home/mcuser/' do
          execute :mkdir, '-p', 'minecraft'
          execute :chown, 'mcuser:mcuser', 'minecraft'
          within :minecraft do
            execute :rm, '-f', 'minecraft_server-run.jar'
            execute :wget, '-O', 'minecraft_server-run.jar', Gamocosm.minecraft_jar_default_url
            execute :chown, 'mcuser:mcuser', 'minecraft_server-run.jar'

            execute :echo, 'eula=true', '>', 'eula.txt'
            execute :chown, 'mcuser:mcuser', 'eula.txt'
          end
        end
        server.update_columns(remote_setup_stage: 4)
        within '/etc/supervisord.d/' do
          execute :rm, '-f', 'minecraft_wrapper.ini'
          execute :wget, '-O', 'minecraft_wrapper.ini', 'https://raw.github.com/Raekye/minecraft-server_wrapper/master/supervisor.conf'
          execute :systemctl, 'start', 'supervisord'
          execute :systemctl, 'enable', 'supervisord'
          execute :supervisorctl, 'reread'
          execute :supervisorctl, 'update'
        end
        within '/tmp/' do
          execute :iptables, '-I', 'INPUT', '-p', 'tcp', '--dport', '5000', '-j', 'ACCEPT'
          execute :iptables, '-I', 'INPUT', '-p', 'tcp', '--dport', '25565', '-j', 'ACCEPT'
          execute :systemctl, 'mask', 'firewalld.service'
          execute :systemctl, 'enable', 'iptables.service'
          execute :systemctl, 'enable', 'ip6tables.service'
          execute :service, 'iptables', 'save'
        end
      end
    end
    server.update_columns(remote_setup_stage: 5)
    StartMinecraftWorker.perform_in(4.seconds, server_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end
