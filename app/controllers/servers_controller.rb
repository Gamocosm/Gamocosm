class ServersController < ApplicationController
  API_ENDPOINTS = [
    :api_status,
    :api_start,
    :api_stop,
    :api_reboot,
    :api_pause,
    :api_resume,
    :api_backup,
    :api_exec,
  ]
  before_action :authenticate_user!, except: API_ENDPOINTS
  skip_before_action :verify_authenticity_token, only: API_ENDPOINTS

  def new
    @server = Server.new
    @server.minecraft = Minecraft.new

    load_new
  end

  def edit
  end

  def show
    @server = find_server(params[:id])
  end

  def load_index
    @friend_servers = current_user.friend_servers
  end

  def load_new
    if !current_user.digital_ocean_missing?
      @do_regions = Gamocosm.digital_ocean.region_list
      @do_sizes = Gamocosm.digital_ocean.size_list
    end
  end

  def index
    @servers = current_user.servers
    load_index
  end

  def create
    begin
      @server = current_user.servers.create!(server_params)
      redirect_to server_path(@server), flash: { success: 'You made a new server! Start it to play' }
    rescue
      @server = Server.new(server_params)
      # run validations for error messages
      @server.valid?
      @do_regions = Gamocosm.digital_ocean.region_list
      @do_sizes = Gamocosm.digital_ocean.size_list
      flash[:error] = 'Something went wrong. Please try again'
      load_new
      render :new
    end
  end

  def update
    @server = find_server_only_owner(params[:id])
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
    @server = find_server_only_owner(params[:id])
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

  def delete
    @server = find_server_only_owner(params[:id])
    render :delete
  end

  def start
    @server = find_server(params[:id])
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
    @server = find_server(params[:id])
    error = @server.stop
    if error
      flash[:error] = "Unable to stop server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server stopping'
    end
    redirect_to server_path(@server)
  end

  def reboot
    @server = find_server(params[:id])
    error = @server.reboot
    if error
      flash[:error] = "Unable to reboot server: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server is rebooting'
    end
    redirect_to server_path(@server)
  end

  def resume
    @server = find_server(params[:id])
    error = @server.minecraft.resume
    if error
      flash[:error] = "Unable to start Minecraft: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server resumed'
    end
    redirect_to server_path(@server)
  end

  def pause
    @server = find_server(params[:id])
    error = @server.minecraft.pause
    if error
      flash[:error] = "Unable to stop Minecraft: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'Server paused'
    end
    redirect_to server_path(@server)
  end

  def backup
    @server = find_server(params[:id])
    error = @server.minecraft.backup
    if error
      flash[:error] = "Unable to backup world: #{error}. Please contact the server admin about this"
    else
      flash[:success] = 'World backed up remotely on server'
    end
    redirect_to server_path(@server)
  end

  def download
    @server = find_server(params[:id])
    error = @server.minecraft.download?
    if error
      return redirect_to server_path(@server), flash: { error: "Unable to download world: #{error}. Please contact the server admin about this" }
    end
    redirect_to @server.minecraft.world_download_url, allow_other_host: true
  end

  def command
    @server = find_server(params[:id])
    command = minecraft_command_params[:data]
    error = @server.minecraft.exec(current_user, command)
    if error
      return redirect_to server_path(@server), flash: { error: "Unable to send command to Minecraft: #{error}. Please contact the server admin about this" }
    end
    redirect_to server_path(@server), flash: { success: 'Command sent' }
  end

  def update_properties
    @server = find_server_only_owner(params[:id])
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
    @server = find_server_only_owner(params[:id])
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
    @server = find_server_only_owner(params[:id])
    email = server_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to server_path(@server), flash: { error: "User #{email} does not exist" }
    end
    @server.friends.delete(friend)
    redirect_to server_path(@server), flash: { success: "User #{email} removed from the server" }
  end

  def autoshutdown_enable
    @server = find_server_only_owner(params[:id])
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    if @server.remote.exists?
      AutoshutdownMinecraftWorker.perform_in(AutoshutdownMinecraftWorker::CHECK_INTERVAL, @server.id)
    end
    redirect_to server_path(@server), flash: { success: 'Autoshutdown enabled' }
  end

  def autoshutdown_disable
    @server = find_server_only_owner(params[:id])
    @server.minecraft.update_columns(autoshutdown_enabled: false)
    redirect_to server_path(@server), flash: { success: 'Autoshutdown disabled' }
  end

  def clear_logs
    @server = find_server_only_owner(params[:id])
    @server.logs.delete_all
    redirect_to server_path(@server), flash: { success: 'Server logs cleared' }
  end

  def api_status
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    active = server[0].running?
    status = server[0].pending_operation
    minecraft = server[0].minecraft.running?
    ip = server[0].remote.exists? ? server[0].remote.ip_address : nil
    download = server[0].minecraft.world_download_url
    render json: {
      server: active,
      status: status,
      minecraft: minecraft,
      ip: ip,
      domain: server[0].host_name,
      download: download,
    }
  end

  def api_start
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].start
    server[0].user.invalidate_digital_ocean_cache_droplets
    server[0].user.invalidate_digital_ocean_cache_volumes
    server[0].user.invalidate_digital_ocean_cache_snapshots
    render json: {
      error: err,
    }
  end

  def api_stop
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].stop
    render json: {
      error: err,
    }
  end

  def api_reboot
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].reboot
    render json: {
      error: err,
    }
  end

  def api_pause
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].minecraft.pause
    render json: {
      error: err,
    }
  end

  def api_resume
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].minecraft.resume
    render json: {
      error: err,
    }
  end

  def api_backup
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].minecraft.backup
    render json: {
      error: err,
    }
  end

  def api_exec
    server = Server.where(id: params[:id], api_key: params[:key])
    if server.length == 0
      render json: {
        error: 'Not found',
      }, status: 404
      return
    end
    err = server[0].minecraft.exec(server[0].user, params[:command])
    render json: {
      error: err,
    }
  end

  def show_digital_ocean_droplets
    @do_droplets = current_user.digital_ocean_droplets
    render layout: nil
  end

  def destroy_digital_ocean_droplet
    error = current_user.digital_ocean.droplet_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_droplets
    if error
      return redirect_to servers_path, flash: { error: error }
    end
    redirect_to servers_path, flash: { notice: 'Deleted droplet on Digital Ocean' }
  end

  def show_digital_ocean_images
    @do_images = current_user.digital_ocean_images
    render layout: nil
  end

  def destroy_digital_ocean_image
    error = current_user.digital_ocean.image_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_images
    if error
      return redirect_to servers_path, flash: { error: error }
    end
    redirect_to servers_path, flash: { notice: 'Deleted snapshot on Digital Ocean' }
  end

  def show_digital_ocean_ssh_keys
    @do_ssh_keys = current_user.digital_ocean_ssh_keys
    render layout: nil
  end

  def add_digital_ocean_ssh_key
    ssh_key_name = params[:digital_ocean_ssh_key][:name]
    ssh_public_key = params[:digital_ocean_ssh_key][:data]
    f = { success: 'Added SSH public key to Digital Ocean' }
    ssh_key = current_user.digital_ocean.ssh_key_create(ssh_key_name, ssh_public_key)
    if ssh_key.error?
      f = { error: ssh_key }
    end
    redirect_back fallback_location: servers_path, flash: f
  end

  def destroy_digital_ocean_ssh_key
    error = current_user.digital_ocean.ssh_key_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_ssh_keys
    f = { success: 'Deleted SSH public key from Digital Ocean' }
    if error
      f = { error: error }
    end
    redirect_back fallback_location: servers_path, flash: f
  end

  def refresh_digital_ocean_cache
    current_user.invalidate
    redirect_to servers_path, flash: { success: 'Cache refreshed' }
  end

  def find_server(id)
    begin
      server = Server.find(id)
    rescue
      raise ActionController::RoutingError.new('Not found')
    end
    if server.owner?(current_user) || server.friend?(current_user)
      return server
    end
    raise ActionController::RoutingError.new('Not found')
  end

  def find_server_only_owner(id)
    begin
      return current_user.servers.find(id)
    rescue
    end
    raise ActionController::RoutingError.new('Not found')
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
    params.require(:minecraft_properties).permit(:allow_flight,
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
      :ops)
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
