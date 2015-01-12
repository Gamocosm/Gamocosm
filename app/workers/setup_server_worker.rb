require 'sshkit/dsl'
require 'timeout'

class SetupServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(user_id, server_id)
    user = User.find(user_id)
    server = Server.find(server_id)
    if !server.remote.exists?
      server.minecraft.log('Error starting server; remote_id is nil. Aborting')
      server.reset_partial
      return
    end
    if server.remote.error?
      server.minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
      server.reset_partial
      return
    end
    host = SSHKit::Host.new(server.remote.ip_address.to_s)
    host.port = !server.done_setup? ? 22 : server.ssh_port
    host.user = 'root'
    host.key = Gamocosm.digital_ocean_ssh_private_key_path
    host.ssh_options = {
      passphrase: Gamocosm.digital_ocean_ssh_private_key_passphrase,
      paranoid: false,
      timeout: 4
    }
    if server.done_setup?
      # Note: this is duplicated below (labeled adding_ssh_keys)
      if !server.ssh_keys.nil?
        begin
          Timeout::timeout(32) {
            ActiveRecord::Base.connection_pool.with_connection do |conn|
              on host do
                within '/' do
                  execute :mkdir, '-p', '/home/mcuser/.ssh/'
                  server.ssh_keys.split(',').each do |key_id|
                    key = user.digital_ocean_ssh_public_key(key_id)
                    if key.error?
                      server.minecraft.log(key)
                    else
                      execute :echo, key.gsub(/["\\]/, ''), '>>', '/home/mcuser/.ssh/authorized_keys'
                    end
                  end
                  execute :chown, '-R', 'mcuser:mcuser', '/home/mcuser/.ssh/'
                  execute :chmod, '700', '/home/mcuser/.ssh/'
                  server.update_columns(ssh_keys: nil)
                end
              end
            end
          }
        rescue Timeout::Error
          server.minecraft.log('Timed out trying to add SSH keys to server. Aborting')
          server.reset_partial
          return
        rescue SSHKit::Runner::ExecuteError => e
          server.minecraft.log("SSH should be up, but got error #{e} trying to add SSH keys to server. Aborting")
          server.reset_partial
          return
        end
      end
    else
      begin
        Timeout::timeout(512) {
          ActiveRecord::Base.connection_pool.with_connection do |conn|
            on host do
              within '/tmp/' do
                server.update_columns(remote_setup_stage: 1)
                if test '! id -u mcuser'
                  execute :adduser, '-m', 'mcuser'
                end
                if server.ssh_keys.nil?
                  execute :echo, "\"#{server.minecraft.user.email.gsub('"', '\"')}+#{server.minecraft.name}\"", '|', :passwd, '--stdin', 'mcuser'
                else
                  # LABEL: adding_ssh_keys
                  execute :mkdir, '-p', '/home/mcuser/.ssh/'
                  server.ssh_keys.split(',').each do |key_id|
                    key = user.digital_ocean_ssh_public_key(key_id)
                    if key.error?
                      server.minecraft.log(key)
                    else
                      execute :echo, key.gsub(/["\\]/, ''), '>>', '/home/mcuser/.ssh/authorized_keys'
                    end
                  end
                  execute :chown, '-R', 'mcuser:mcuser', '/home/mcuser/.ssh/'
                  execute :chmod, '700', '/home/mcuser/.ssh/'
                  server.update_columns(ssh_keys: nil)
                end
                execute :usermod, '-aG', 'wheel', 'mcuser'
                server.update_columns(remote_setup_stage: 2)
                execute :yum, '-y', 'update'
                execute :yum, '-y', 'install', 'java-1.7.0-openjdk-headless', 'python3', 'python3-devel', 'python3-pip', 'git', 'tmux'
                execute :rm, '-rf', 'pip_build_root'
                execute 'python3-pip', 'install', 'flask'
              end
              within '/opt/' do
                execute :rm, '-rf', 'gamocosm'
                execute :mkdir, '-p', 'gamocosm'
                within :gamocosm do
                  execute :git, 'clone', Gamocosm.minecraft_server_wrapper_git_url, '.'
                  execute :echo, "\"#{Gamocosm.minecraft_wrapper_username}\"", '>', 'mcsw-auth.txt'
                  execute :echo, "\"#{server.minecraft.minecraft_wrapper_password}\"", '>>', 'mcsw-auth.txt'
                end
                execute :chown, '-R', 'mcuser:mcuser', 'gamocosm'
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
                  execute :echo, 'enable-query=true', '>', 'server.properties'
                  execute :chown, 'mcuser:mcuser', 'server.properties'
                end
              end
              server.update_columns(remote_setup_stage: 4)
              within '/etc/systemd/system/' do
                execute 'cp', '/opt/gamocosm/mcsw.service', 'mcsw.service'
                execute 'systemctl', 'enable', 'mcsw'
                execute 'systemctl', 'start', 'mcsw'
              end
              within '/tmp/' do
                execute 'firewall-cmd', '--add-port=5000/tcp'
                execute 'firewall-cmd', '--permanent', '--add-port=5000/tcp'
                execute 'firewall-cmd', '--add-port=25565/tcp'
                execute 'firewall-cmd', '--permanent', '--add-port=25565/tcp'
                execute 'firewall-cmd', '--add-port=25565/udp'
                execute 'firewall-cmd', '--permanent', '--add-port=25565/udp'
                execute :fallocate, '-l', '1G', '/swapfile'
                execute :chmod, '600', '/swapfile'
                execute :mkswap, '/swapfile'
                execute :swapon, '/swapfile'
                execute :echo, '/swapfile none swap defaults 0 0', '>>', '/etc/fstab'
                if server.ssh_port != 22
                  execute 'firewall-cmd', "--add-port=#{server.ssh_port}/tcp"
                  execute 'firewall-cmd', '--permanent', "--add-port=#{server.ssh_port}/tcp"
                  execute :sed, '-i', "'s/^#Port 22$/Port #{server.ssh_port}/'", '/etc/ssh/sshd_config'
                  execute :systemctl, 'restart', 'sshd'
                end
              end
            end
          end
        }
      rescue Timeout::Error
        server.minecraft.log('Timed out setting up server. Aborting')
        server.reset_partial
        return
      rescue SSHKit::Runner::ExecuteError => e
        server.minecraft.log("SSH should be up, but got error #{e} trying to setup server. Aborting")
        server.reset_partial
        return
      end
    end
    server.update_columns(remote_setup_stage: 5)
    StartMinecraftWorker.perform_in(4.seconds, server_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server = Server.find(server_id)
    server.minecraft.log("Background job setting up server failed: #{e}")
    server.reset_partial
    raise
  end
end
