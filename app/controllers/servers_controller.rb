class ServersController < ApplicationController
  before_action :authenticate_user!

  def index
    @servers = current_user.servers
    @friend_servers = current_user.friend_servers
  end

  def show
    @server = find_server
  end

  def new
    @server = Server.new
    @server.minecraft = Minecraft.new
    @do_regions = Gamocosm.digital_ocean.region_list
    @do_sizes = Gamocosm.digital_ocean.size_list
  end

  def create
    begin
      @server = current_user.servers.create!(server_params)
      redirect_to server_path(@server), flash: { success: 'You made a new server! Start it to play' }
    rescue
      @server = Server.new(server_params)
      # run validations for error messages
      @server.valid?
      flash[:error] = 'Something went wrong. Please try again'

      @do_regions = Gamocosm.digital_ocean.region_list
      @do_sizes = Gamocosm.digital_ocean.size_list
      render :new
    end
  end

  def update
    @server = find_server_only_owner
    # can be ftp ssh tab, schedule tab, or advanced tab
    ssh_keys = server_ssh_keys_params[:ssh_keys]
    if ssh_keys.nil?
      p = server_schedule_params
      @server_tab = :schedule
      schedule_text = nil
      if p[:timezone_delta].nil?
        p = server_advanced_params
        if !p[:minecraft_attributes].nil?
          p[:minecraft_attributes][:id] = @server.minecraft.id
        end
        @server_tab = :advanced
      else
        if !p[:minecraft_attributes].nil?
          p[:minecraft_attributes][:id] = @server.minecraft.id
        end
        schedule_text = p.delete(:schedule_text)
      end
      if @server.update(p)
        if @server_tab != :schedule || @server.parse_and_save_schedule(schedule_text)
          return redirect_to server_path(@server), flash: { success: (@server_tab == :schedule ? 'Server schedule updated' : 'Server advanced configuration updated') }
        end
      end
    else
      @server.ssh_keys = ssh_keys
      if @server.save
        message = 'Server SSH keys updated'
        if !@server.ssh_keys.blank?
          message += '. They will be added the next time you start the server'
        end
        return redirect_to server_path(@server), flash: { success: message }
      end
      @server_tab = :ftp_ssh
    end
    flash[:error] = 'Something went wrong. Please try again'
    render :show
  end

  def destroy
    @server = find_server_only_owner
    if !@server.preserve_snapshot
      error = @server.remote.destroy_saved_snapshot
      if error
        return redirect_to server_path(@server), flash: { error: "Unable to delete saved server snapshot: #{error}" }
      end
    end
    error = @server.remote.destroy
    if error
      return redirect_to server_path(@server), flash: { error: "Unable to delete server: #{error}" }
    end
    @server.delete
    redirect_to servers_path, flash: { success: 'Server is deleting' }
  end

  def confirm_delete
    @server = find_server_only_owner
  end

  def start
    @server = find_server
    error = @server.start
    if error
      flash[:error] = "Unable to start server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server starting'
    end
    @server.user.invalidate_digital_ocean_cache_droplets
    @server.user.invalidate_digital_ocean_cache_volumes
    @server.user.invalidate_digital_ocean_cache_snapshots
    redirect_to server_path(@server)
  end

  def stop
    @server = find_server
    error = @server.stop
    if error
      flash[:error] = "Unable to stop server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server stopping'
    end
    redirect_to server_path(@server)
  end

  def reboot
    @server = find_server
    error = @server.reboot
    if error
      flash[:error] = "Unable to reboot server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server is rebooting'
    end
    redirect_to server_path(@server)
  end

  def resume
    @server = find_server
    error = @server.minecraft.resume
    if error
      flash[:error] = "Unable to start Minecraft: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server resumed'
    end
    redirect_to server_path(@server)
  end

  def pause
    @server = find_server
    error = @server.minecraft.pause
    if error
      flash[:error] = "Unable to stop Minecraft: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server paused'
    end
    redirect_to server_path(@server)
  end

  def backup
    @server = find_server
    error = @server.minecraft.backup
    if error
      flash[:error] = "Unable to backup world: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'World backed up remotely on server'
    end
    redirect_to server_path(@server)
  end

  def download
    @server = find_server
    error = @server.minecraft.download?
    if error
      return redirect_to server_path(@server), flash: { error: "Unable to download world: #{error}. Please contact the server admin about this" }
    end
    redirect_to @server.minecraft.world_download_url, allow_other_host: true
  end

  def command
    @server = find_server
    command = minecraft_command_params[:data]
    error = @server.minecraft.exec(current_user, command)
    if error
      return redirect_to server_path(@server), flash: { error: "Unable to send command to Minecraft: #{error}. Please contact the server admin about this" }
    end
    redirect_to server_path(@server), flash: { success: 'Command sent' }
  end

  def update_properties
    @server = find_server_only_owner
    if !@server.running?
      return redirect_to server_path(@server), flash: { error: 'Server isn\'t running. Start it to edit Minecraft properties' }
    end
    res = @server.minecraft.node.update_properties(minecraft_properties_params)
    if res.error?
      return redirect_to server_path(@server), flash: { error: "Unable to update Minecraft properties: #{res}. Please contact the server admin about this" }
    end
    redirect_to server_path(@server), flash: { success: 'Minecraft properties updated' }
  end

  def add_friend
    @server = find_server_only_owner
    email = server_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to server_path(@server), flash: { error: "User #{email} does not exist" }
    end
    if @server.owner?(friend)
      return redirect_to server_path(@server), notice: 'You are already the owner of the server'
    end
    if @server.friend?(friend)
      return redirect_to server_path(@server), notice: "User #{email} is already on this server"
    end
    @server.friends << friend
    redirect_to server_path(@server), flash: { success: "User #{email} added to the server" }
  end

  def remove_friend
    @server = find_server_only_owner
    email = server_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to server_path(@server), flash: { error: "User #{email} does not exist" }
    end
    @server.friends.delete(friend)
    redirect_to server_path(@server), flash: { success: "User #{email} removed from the server" }
  end

  def autoshutdown_enable
    @server = find_server_only_owner
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    if @server.remote.exists?
      AutoshutdownMinecraftWorker.perform_in(AutoshutdownMinecraftWorker::CHECK_INTERVAL, @server.id)
    end
    redirect_to server_path(@server), flash: { success: 'Autoshutdown enabled' }
  end

  def autoshutdown_disable
    @server = find_server_only_owner
    @server.minecraft.update_columns(autoshutdown_enabled: false)
    redirect_to server_path(@server), flash: { success: 'Autoshutdown disabled' }
  end

  def clear_logs
    @server = find_server_only_owner
    @server.logs.delete_all
    redirect_to server_path(@server), flash: { success: 'Server logs cleared' }
  end

  def refresh_digital_ocean_cache
    current_user.invalidate
    redirect_to servers_path, flash: { success: 'Cache refreshed' }
  end

  private
  def find_server
    begin
      server = Server.find(params[:id])
    rescue
      raise ActionController::RoutingError, 'Not found'
    end
    if server.owner?(current_user) || server.friend?(current_user)
      return server
    end
    raise ActionController::RoutingError, 'Not found'
  end

  def find_server_only_owner
    begin
      current_user.servers.find(params[:id])
    rescue
      raise ActionController::RoutingError, 'Not found'
    end
  end

  def server_params
    params.require(:server).permit(
      :name,
      :remote_region_slug,
      :remote_size_slug,
      minecraft_attributes: [:flavour],
    )
  end

  def minecraft_properties_params
    params.require(:minecraft_properties).permit(
      :allow_flight,
      :allow_nether,
      :announce_player_achievements,
      :difficulty,
      :enable_command_block,
      :force_gamemode,
      :gamemode,
      :generate_structures,
      :generator_settings,
      :hardcore,
      :level_seed,
      :level_type,
      :max_build_height,
      :motd,
      :online_mode,
      :op_permission_level,
      :player_idle_timeout,
      :pvp,
      :spawn_animals,
      :spawn_monsters,
      :spawn_npcs,
      :spawn_protection,
      :white_list,
      :whitelist,
      :ops,
    )
  end

  def server_friend_params
    params.require(:server_friend).permit(:email)
  end

  def server_advanced_params
    params.require(:server).permit(
      :ssh_port,
      :setup_stage,
      :pending_operation,
      :remote_snapshot_id,
      :remote_region_slug,
      :remote_size_slug,
      :api_key,
      :preserve_snapshot,
      minecraft_attributes: [:mcsw_password],
    )
  end

  def server_ssh_keys_params
    params.require(:server).permit(:ssh_keys)
  end

  def server_schedule_params
    params.require(:server).permit(
      :timezone_delta,
      :schedule_text,
      minecraft_attributes: [:autoshutdown_minutes],
    )
  end

  def minecraft_command_params
    params.require(:command).permit(:data)
  end
end
