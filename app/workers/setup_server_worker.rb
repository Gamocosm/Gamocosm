require 'sshkit'
require 'sshkit/dsl'
include SSHKit::DSL
require 'timeout'

class SetupServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  CHECK_INTERVAL = Rails.env.test? ? 2.seconds : 16.seconds

  SYSTEM_PACKAGES = [
    'firewalld',
    'policycoreutils-python-utils',
    'cockpit',
    'python3',
    'python3-devel',
    'python3-pip',
    'python3-systemd',
    'vim',
    'git',
    'tmux',
    'unzip',
  ]

  def perform(server_id, times = 0)
    logger.info "Running #{self.class.name} with server_id #{server_id}, times #{times}"
    server = Server.find(server_id)
    user = server.user
    begin
      if !server.remote.exists?
        server.log('Error starting server; remote_id is nil. Aborting')
        server.reset_state
        return
      end
      if server.remote.error?
        server.log("Error communicating with Digital Ocean while starting server: #{server.remote.error}. Aborting")
        server.reset_state
        return
      end
      # see https://github.com/capistrano/sshkit/blob/master/lib/sshkit/host.rb
      host = SSHKit::Host.new(server.remote.ip_address)
      host.port = !server.done_setup? ? 22 : server.ssh_port
      host.user = 'root'
      # see https://net-ssh.github.io/net-ssh/Net/SSH.html
      host.ssh_options = {
        keys: [ Gamocosm::DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH ],
        passphrase: Gamocosm::DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE,
        verify_host_key: :never,
        # how long to wait for initial connection
        # `e.cause` will be `Timeout::Error`
        timeout: 4,
      }
      begin
        on host do
          execute :true
        end
      rescue SSHKit::Runner::ExecuteError => e
        logger.info "Debugging #{self.class}: SSHKit error: #{e.inspect}, #{e.cause.inspect}"
        logger.info e.backtrace.join("\n")
        times += 1
        if times >= 12
          server.log('Error connecting to server; failed to SSH. Aborting')
          server.reset_state
          logger.error "#{self.class.name} could not SSH into server #{server_id}"
          return
        end
        #if e.cause.is_a?(Timeout::Error)
        #  server.log("Server started, but timed out while trying to SSH (attempt #{times}, #{e}). Trying again in #{CHECK_INTERVAL} seconds")
        #  SetupServerWorker.perform_in(CHECK_INTERVAL, server_id, times)
        #  return
        #end
        if e.cause.is_a?(Errno::EHOSTUNREACH)
          server.log("Server started, but unreachable while trying to SSH (attempt #{times}, #{e}). Trying again in #{CHECK_INTERVAL} seconds")
          SetupServerWorker.perform_in(CHECK_INTERVAL, server_id, times)
          return
        end
        if e.cause.is_a?(Errno::ECONNREFUSED)
          server.log("Server started, but connection refused while trying to SSH (attempt #{times}, #{e}). Trying again in #{CHECK_INTERVAL} seconds")
          SetupServerWorker.perform_in(CHECK_INTERVAL, server_id, times)
          return
        end
        if e.cause.is_a?(Net::SSH::ConnectionTimeout)
          server.log("Server started, but connection timed out while trying to SSH (attempt #{times}, #{e}). Trying again in #{CHECK_INTERVAL} seconds")
          SetupServerWorker.perform_in(CHECK_INTERVAL, server_id, times)
          return
        end
        if e.cause.is_a?(SSHKit::Command::Failed)
          logger.error "SSHKit running 'true' failed. Trying again in #{CHECK_INTERVAL} seconds"
          server.log("Server started and SSH connected, but test command 'true' failed (attempt #{times}, #{e}). Trying again in #{CHECK_INTERVAL} seconds")
          SetupServerWorker.perform_in(CHECK_INTERVAL, server_id, times)
          return
        end
        raise
      end
      self.enable_ssh_password(server, host)
      if server.done_setup?
        self.setup_volume(server, host)
        self.base_update(user, server, host)
        self.add_ssh_keys(user, server, host)
      else
        server.update_columns(setup_stage: 1)
        self.base_install(user, server, host)
        server.update_columns(setup_stage: 2)
        self.add_ssh_keys(user, server, host)
        server.update_columns(setup_stage: 3)
        self.setup_volume(server, host)
        self.install_minecraft(user, server, host)
        self.install_mcsw(user, server, host)
        server.update_columns(setup_stage: 4)
        self.modify_ssh_port(user, server, host)
        server.update_columns(setup_stage: 5)
      end
      StartMinecraftWorker.perform_in(4.seconds, server_id)
    rescue => e
      server.log("Background job setting up server failed: #{e}")
      server.reset_state
      logger.error "Debugging #{self.class}: unhandled error: #{e.inspect}, #{e.cause.inspect}"
      logger.error e.backtrace.join("\n")
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

  def enable_ssh_password(server, host)
    begin
      on host do
        Timeout::timeout(16) do
          within '/etc/ssh' do
            execute :sed, '-i', '"1i PasswordAuthentication yes"', 'sshd_config'
            execute :sed, '-i', '"/PasswordAuthentication no/d"', 'sshd_config'
            execute :systemctl, 'restart', 'sshd'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long doing base setup. Please re-create the server and try again'
      end
      raise e
    end
  end

  def base_install(user, server, host)
    mcuser_password_escaped = "#{user.email}+#{server.name}".shellescape
    begin
      on host do
        Timeout::timeout(600) do
          within '/tmp/' do
            # setup user
            if ! test 'id -u mcuser'
              execute :adduser, '-m', 'mcuser'
            end
            execute :echo, mcuser_password_escaped, '|', :passwd, '--stdin', 'mcuser'
            execute :usermod, '-aG', 'wheel', 'mcuser'

            # setup swap
            if test '[ ! -f /swapfile ]'
              execute :echo, '/swapfile none swap defaults 0 0', '>>', '/etc/fstab'
            end
            execute :rm, '-f', '/swapfile'
            execute :touch, '/swapfile'
            execute :chattr, '+C', '/swapfile'
            execute :fallocate, '-l', '1G', '/swapfile'
            execute :chmod, '600', '/swapfile'
            execute :mkswap, '/swapfile'
            execute :swapon, '--all'

            # install system packages
            execute :dnf, '-y', 'install', *SYSTEM_PACKAGES
            execute :systemctl, 'start', 'firewalld'
            # firewalld is enabled upon install
            execute :systemctl, 'start', 'cockpit.socket'
            execute :systemctl, 'enable', 'cockpit.socket'
            execute :'firewall-cmd', '--add-service=cockpit'
            execute :'firewall-cmd', '--add-service=cockpit', '--permanent'
            execute :'firewall-cmd', "--add-port=#{Minecraft::Node::MCSW_PORT}/tcp"
            execute :'firewall-cmd', "--add-port=#{Minecraft::Node::MCSW_PORT}/tcp", '--permanent'
            execute :'firewall-cmd', '--add-port=25565/tcp'
            execute :'firewall-cmd', '--permanent', '--add-port=25565/tcp', '--permanent'
            execute :'firewall-cmd', '--add-port=25565/udp'
            execute :'firewall-cmd', '--add-port=25565/udp', '--permanent'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long doing base setup. Please re-create the server and try again'
      end
      raise e
    end
  end

  def base_update(user, server, host)
    begin
      on host do
        Timeout::timeout(60) do
          within '/' do
            # for old servers (prior to 2020 April 8)
            if ! test 'dnf repoquery --installed | grep -q python3-systemd'
              execute :dnf, '-y', 'install', 'python3-systemd'
            end
            if ! test 'su mcuser -c "pip3 freeze" | grep -q Flask'
              execute :rm, '-rf', '/tmp/pip_build_root'
              execute :su, 'mcuser', '-c', '"pip3 install --user flask"'
            end
          end
          if ! test '[ -e /opt/gamocosm/noupdate ]'
            within '/opt/gamocosm/' do
              execute :su, 'mcuser', '-c', '"git fetch origin master"'
              execute :su, 'mcuser', '-c', '"git reset --hard origin/master"'
              execute :cp, '-f', 'run_mcsw.sh', '/usr/local/bin/run_mcsw.sh'
              execute :cp, '-f', 'mcsw.service', '/etc/systemd/system/mcsw.service'
              execute :systemctl, 'daemon-reload'
              execute :systemctl, 'restart', 'mcsw'
            end
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long doing update. Please try again'
      end
      raise e
    end
  end

  def setup_volume(server, host)
    volume = server.volume
    begin
      on host do
        Timeout::timeout(30) do
          within '/home/mcuser/' do
            if volume.nil?
              execute :mkdir, '-p', 'minecraft'
            else
              if volume.snapshot?
                server.log('Started server with volume, but volume status is "snapshot". The volume will not be attached')
                execute :mkdir, '-p', 'minecraft'
              elsif volume.volume?
                mount_path = volume.mount_path
                if ! test "mountpoint -q #{mount_path}"
                  execute :mkdir, '-p', mount_path
                  execute :mount, '-o', 'defaults,nofail,discard,noatime', volume.device_path, mount_path
                end
                mount_minecraft_path = "#{mount_path}/minecraft"
                execute :mkdir, '-p', mount_minecraft_path
                if ! test '[ -e /home/mcuser/minecraft ]'
                  execute :ln, '-s', mount_minecraft_path, 'minecraft'
                end
              else
                raise 'Badness'
              end
            end
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long setting up the volume. Please try again'
      end
      raise e
    end
  end

  def install_minecraft(user, server, host)
    begin
      fi = server.minecraft.flavour_info
      if fi.nil?
        server.log("Flavour #{server.minecraft.flavour} not found! Installing default vanilla")
        server.minecraft.update_columns(flavour: Gamocosm::MINECRAFT_FLAVOURS.first[0])
        fi = Gamocosm::MINECRAFT_FLAVOURS.first[1]
      end
      fv = server.minecraft.flavour.split('/')
      minecraft_script = "/tmp/gamocosm-minecraft-flavours/#{fv[0]}.sh"
      mc_flavours_git_url = Gamocosm::MINECRAFT_FLAVOURS_GIT_URL
      on host do
        # estimated minutes * 60 secs/minute * 2 (buffer)
        Timeout::timeout(fi[:time] * 60 * 2) do
          within '/tmp/' do
            execute :rm, '-rf', 'gamocosm-minecraft-flavours'
            execute :git, 'clone', mc_flavours_git_url, 'gamocosm-minecraft-flavours'
          end
          within '/home/mcuser/' do
            within :minecraft do
              execute :chmod, 'u+x', minecraft_script
              with minecraft_flavour_version: fv[1] do
                execute :bash, '-c', minecraft_script
              end
            end
            execute :chown, 'mcuser:mcuser', 'minecraft'
            execute :chown, '-R', 'mcuser:mcuser', 'minecraft/'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long installing Minecraft. Please try again'
      end
      raise e
    end
  end

  def install_mcsw(user, server, host)
    mcsw_git_url = Gamocosm::MCSW_GIT_URL
    mcsw_username = Gamocosm::MCSW_USERNAME
    mcsw_password = server.minecraft.mcsw_password
    begin
      on host do
        Timeout::timeout(90) do
          within '/opt/' do
            execute :rm, '-rf', '/tmp/pip_build_root'
            execute :su, 'mcuser', '-c', '"pip3 install --user flask"'
            execute :rm, '-rf', 'gamocosm'
            execute :git, 'clone', mcsw_git_url, 'gamocosm'
            within :gamocosm do
              execute :echo, mcsw_username, '>', 'mcsw-auth.txt'
              execute :echo, mcsw_password, '>>', 'mcsw-auth.txt'
              execute :cp, '-f', 'mcsw.service', '/etc/systemd/system/mcsw.service'
              execute :cp, '-f', 'run_mcsw.sh', '/usr/local/bin/run_mcsw.sh'
              execute :checkmodule, '-M', '-m', '-o', 'mcsw.mod', 'mcsw.te'
              execute :semodule_package, '-m', 'mcsw.mod', '-o', 'mcsw.pp'
              execute :semodule, '-i', 'mcsw.pp'
            end
            execute :chown, '-R', 'mcuser:mcuser', 'gamocosm'
            execute :systemctl, 'enable', 'mcsw'
            execute :systemctl, 'start', 'mcsw'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long setting up Minecraft server wrapper. Please try again'
      end
      raise e
    end
  end

  def modify_ssh_port(user, server, host)
    ssh_port = server.ssh_port
    if ssh_port == 22
      return
    end
    begin
      on host do
        Timeout::timeout(60) do
          within '/etc/ssh/' do
            execute :'firewall-cmd', "--add-port=#{ssh_port}/tcp"
            execute :'firewall-cmd', '--permanent', "--add-port=#{ssh_port}/tcp"
            if ! test "semanage port -l | grep ssh | grep -q #{ssh_port}"
              # see `/etc/ssh/sshd_config`
              execute :semanage, 'port', '-a', '-t', 'ssh_port_t', '-p', 'tcp', ssh_port
            end
            execute :sed, '-i', "'1i Port #{ssh_port}'", 'sshd_config'
            execute :systemctl, 'restart', 'sshd'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long modifying SSH port. Please try again'
      end
      raise e
    end
  end

  def add_ssh_keys(user, server, host)
    if server.ssh_keys.nil?
      return
    end
    key_contents = []
    server.ssh_keys.split(',').each do |key_id|
      key = user.digital_ocean.ssh_key_show(key_id)
      if key.error?
        server.log(key)
      else
        key_contents.push(key.public_key.shellescape)
      end
    end
    server.update_columns(ssh_keys: nil)
    if key_contents.empty?
      return
    end
    begin
      on host do
        Timeout::timeout(30) do
          within '/tmp/' do
            execute :mkdir, '-p', '/home/mcuser/.ssh/'
            key_contents.each do |key_escaped|
              execute :echo, key_escaped, '>>', '/home/mcuser/.ssh/authorized_keys'
            end
            execute :chown, '-R', 'mcuser:mcuser', '/home/mcuser/.ssh/'
            execute :chmod, '700', '/home/mcuser/.ssh/'
            execute :chmod, '600', '/home/mcuser/.ssh/authorized_keys'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long adding SSH keys. Please try again'
      end
      raise e
    end
  end
end
