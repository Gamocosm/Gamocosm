class MinecraftServersController < ApplicationController
  before_filter :authenticate_user!

  def index
    @servers = current_user.minecraft_servers
    @server = MinecraftServer.new
    @droplets = current_user.digital_ocean_droplets
    @snapshots = current_user.digital_ocean_snapshots
  end

  def new
  end

  def create
    @server = current_user.minecraft_servers.new(minecraft_server_params)
    if @server.save
      return redirect_to minecraft_server_path(@server), notice: 'Server created'
    else
      flash.now[:error] = 'Something went wrong. Please try again'
      return render :index
    end
  end

  def show
    @server = current_user.minecraft_servers.find(params[:id])
  end

  def start
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.start
      flash_message = 'Server starting'
    else
      flash_message = 'Unable to start server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def stop
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.stop
      return redirect_to minecraft_servers_path, notice: 'Server is stopping'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to stop server'
  end

  def resume
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.resume
      flash_message = 'Server resumed'
    else
      flash_message = 'Unable to resume server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def pause
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.pause
      flash_message = 'Server paused'
    else
      flash_message = 'Unable to pause server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def backup
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.backup
      flash_message = 'World backed up locally on your droplet'
    else
      flash_message = 'Unable to backup server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def download
    @server = current_user.minecraft_servers.find(params[:id])
    return redirect_to @server.world_download_url
  end

  def edit
  end

  def update
    @server = current_user.minecraft_servers.find(params[:id])
    if params.require(:minecraft_server).has_key? :remote_setup_stage
      params[:minecraft_server][:remote_setup_stage] = 2
    end
    if @server.update_attributes(params.require(:minecraft_server).permit(:name, :remote_setup_stage))
      return redirect_to minecraft_server_path(@server), notice: 'Server updated'
    end
    return redirect_to minecraft_server_path(@server), error: 'Unable to update server'
  end

  def update_minecraft_properties
    @server = current_user.minecraft_servers.find(params[:id])
    properties = @server.properties
    if properties.nil?
      return redirect_to minecraft_server_path(@server), error: 'Unable to update server properties; droplet is off'
    end
    if properties.update(minecraft_server_properties_params)
      return redirect_to minecraft_server_path(@server), notice: 'Minecraft properties updated'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to update Minecraft properties'
  end

  def destroy
    @server = current_user.minecraft_servers.find(params[:id])
    response = @server.droplet.remote.destroy
    if response
      @server.destroy
      return redirect_to minecraft_servers_path, notice: 'Server is deleting'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to delete server'
  end

  def minecraft_server_params
    return params.require(:minecraft_server).permit(:name, :digital_ocean_droplet_size_id)
  end

  def minecraft_server_properties_params
    return params.require(:minecraft_server_properties).permit(:allow_flight,
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
end
