require 'sshkit'
require 'sshkit/dsl'
include SSHKit::DSL
require 'timeout'

class String
  def shell_escape
    return "'#{self.gsub('\'', '\'"\'"\'')}'"
  end
end

class SetupServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  SYSTEM_PACKAGES = [
    'firewalld',
    'java-1.8.0-openjdk-headless',
    'python3',
    'python3-devel',
    'python3-pip',
    'git',
    'tmux',
    'unzip',
    'wget',
    'policycoreutils-python-utils',
  ]

  ZRAM_SYSTEMD_SERVICE_FILE_URL = 'https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/server_setup/zram.service'
  ZRAM_HELPER_SCRIPT_URL = 'https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/server_setup/zram-helper.sh'

  def perform(server_id, times = 0)
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
      host = SSHKit::Host.new(server.remote.ip_address.to_s)
      host.port = !server.done_setup? ? 22 : server.ssh_port
      host.user = 'root'
      host.key = Gamocosm::DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH
      host.ssh_options = {
        passphrase: Gamocosm::DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE,
        paranoid: false,
        # how long to wait for initial connection
        # `e.cause` will be `Timeout::Error`
        timeout: 4
      }
      begin
        on host do
          execute :true
        end
      rescue SSHKit::Runner::ExecuteError => e
        logger.error "Debugging #{self.class}: SSHKit error: #{e.inspect}, #{e.cause.inspect}"
        logger.error e.backtrace.join("\n")
        if times == 11
          server.log('Error connecting to server; failed to SSH. Aborting')
          server.reset_state
          return
        end
        if e.cause.is_a?(Timeout::Error)
          server.log("Server started, but timed out while trying to SSH (attempt #{times}, #{e}). Trying again in 16 seconds")
          SetupServerWorker.perform_in(16.seconds, server_id, times + 1)
          return
        end
        if e.cause.is_a?(Errno::EHOSTUNREACH)
          server.log("Server started, but unreachable while trying to SSH (attempt #{times}, #{e}). Trying again in 16 seconds")
          SetupServerWorker.perform_in(16.seconds, server_id, times + 1)
          return
        end
        if e.cause.is_a?(Errno::ECONNREFUSED)
          server.log("Server started, but connection refused while trying to SSH (attempt #{times}, #{e}). Trying again in 16 seconds")
          SetupServerWorker.perform_in(16.seconds, server_id, times + 1)
          return
        end
        if e.cause.is_a?(Net::SSH::ConnectionTimeout)
          server.log("Server started, but connection timed out while trying to SSH (attempt #{times}, #{e}). Trying again in 16 seconds")
          SetupServerWorker.perform_in(16.seconds, server_id, times + 1)
          return
        end
        raise
      end
      if server.done_setup?
        self.base_update(user, server, host)
        self.add_ssh_keys(user, server, host)
      else
        server.update_columns(setup_stage: 1)
        self.base_install(user, server, host)
        server.update_columns(setup_stage: 2)
        self.add_ssh_keys(user, server, host)
        server.update_columns(setup_stage: 3)
        self.install_minecraft(user, server, host)
        self.install_mcsw(user, server, host)
        server.update_columns(setup_stage: 4)
        self.modify_ssh_port(user, server, host)
      end
      server.update_columns(setup_stage: 5)
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

  def base_install(user, server, host)
    mcuser_password_escaped = "#{user.email}+#{server.name}".shell_escape
    server_ram_below_4gb = ['512mb', '1gb', '2gb'].include?(server.remote_size_slug)
    begin
      on host do
        Timeout::timeout(512) do
          within '/tmp/' do
            # setup user
            if ! test 'id -u mcuser'
              execute :adduser, '-m', 'mcuser'
            end
            execute :echo, mcuser_password_escaped, '|', :passwd, '--stdin', 'mcuser'
            execute :usermod, '-aG', 'wheel', 'mcuser'

            # setup zram
            execute :curl, '-s', '-o', '/etc/systemd/system/zram.service', "'#{ZRAM_SYSTEMD_SERVICE_FILE_URL}'"
            execute :curl, '-s', '-o', '/usr/bin/zram-helper', "'#{ZRAM_HELPER_SCRIPT_URL}'"
            execute :chmod, '+x', '/usr/bin/zram-helper'
            if server_ram_below_4gb
              execute :systemctl, 'enable', 'zram'
              execute :systemctl, 'start', 'zram'
            end

            # setup swap
            if test '[ ! -f "/swapfile" ]'
              execute :fallocate, '-l', '1G', '/swapfile'
              execute :chmod, '600', '/swapfile'
              execute :mkswap, '/swapfile'
              execute :swapon, '/swapfile'
              execute :echo, '/swapfile none swap defaults 0 0', '>>', '/etc/fstab'
            end

            # install system packages
            execute :dnf, '-y', 'install', *SYSTEM_PACKAGES
            execute :systemctl, 'start', 'firewalld'
            execute :'firewall-cmd', '--add-port=5000/tcp'
            execute :'firewall-cmd', '--permanent', '--add-port=5000/tcp'
            execute :'firewall-cmd', '--add-port=25565/tcp'
            execute :'firewall-cmd', '--permanent', '--add-port=25565/tcp'
            execute :'firewall-cmd', '--add-port=25565/udp'
            execute :'firewall-cmd', '--permanent', '--add-port=25565/udp'
            execute :rm, '-rf', '/tmp/pip_build_root'
            execute :pip3, 'install', 'flask'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long doing base setup. Please try again'
      end
      raise e
    end
  end

  def base_update(user, server, host)
    mcsw_git_url = Gamocosm::MCSW_GIT_URL
    begin
      on host do
        Timeout::timeout(16) do
          within '/opt/gamocosm/' do
            execute :su, 'mcuser', '-c', "'git remote set-url origin \"#{mcsw_git_url}\"'"
            execute :su, 'mcuser', '-c', '"git checkout master"'
            execute :su, 'mcuser', '-c', '"git fetch origin master"'
            execute :su, 'mcuser', '-c', '"git reset --hard origin/master"'
            execute :cp, '-f', '/opt/gamocosm/mcsw.service', '/etc/systemd/system/mcsw.service'
            execute :systemctl, 'daemon-reload'
            execute :systemctl, 'restart', 'mcsw'
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
            execute :mkdir, '-p', 'minecraft'
            within :minecraft do
              execute :chmod, 'u+x', minecraft_script
              with minecraft_flavour_version: fv[1] do
                execute :bash, '-c', minecraft_script
              end
            end
            execute :chown, '-R', 'mcuser:mcuser', 'minecraft'
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
        Timeout::timeout(16) do
          within '/opt/' do
            execute :rm, '-rf', 'gamocosm'
            execute :git, 'clone', mcsw_git_url, 'gamocosm'
            within :gamocosm do
              execute :echo, mcsw_username, '>', 'mcsw-auth.txt'
              execute :echo, mcsw_password, '>>', 'mcsw-auth.txt'
            end
            execute :chown, '-R', 'mcuser:mcuser', 'gamocosm'
          end
          within '/etc/systemd/system/' do
            execute :cp, '/opt/gamocosm/mcsw.service', 'mcsw.service'
            execute :systemctl, 'enable', 'mcsw'
            execute :systemctl, 'start', 'mcsw'
          end
        end
      end
    rescue SSHKit::Runner::ExecuteError => e
      if e.cause.is_a?(Timeout::Error)
        raise 'Server setup (SSH): Server stalled/took too long setting up Minecraft. Please try again'
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
        Timeout::timeout(64) do
          within '/tmp/' do
            execute :'firewall-cmd', "--add-port=#{ssh_port}/tcp"
            execute :'firewall-cmd', '--permanent', "--add-port=#{ssh_port}/tcp"
            if ! test "semanage port -l | grep ssh | grep -q #{ssh_port}"
              # see `/etc/ssh/sshd_config`
              execute :semanage, 'port', '-a', '-t', 'ssh_port_t', '-p', 'tcp', ssh_port
            end
            execute :sed, '-i', "'s/^#Port 22$/Port #{ssh_port}/'", '/etc/ssh/sshd_config'
            execute :sed, '-i', "'s/^PasswordAuthentication no/PasswordAuthentication yes/'", '/etc/ssh/sshd_config'
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
        key_contents.push(key.public_key.shell_escape)
      end
    end
    server.update_columns(ssh_keys: nil)
    if key_contents.empty?
      return
    end
    begin
      on host do
        Timeout::timeout(32) do
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
