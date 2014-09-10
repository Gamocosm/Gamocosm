class MinecraftServersController < ApplicationController
  before_action :authenticate_user!

  def load_index
    @servers = current_user.minecraft_servers
    @server = MinecraftServer.new
    @droplets = current_user.digital_ocean_droplets
    @snapshots = current_user.digital_ocean_snapshots
    @friend_minecraft_servers = current_user.friend_minecraft_servers
  end

  def index
    load_index
  end

  def new
  end

  def create
    @server = current_user.minecraft_servers.new(minecraft_server_params)
    if @server.save
      @server.create_droplet
      return redirect_to minecraft_server_path(@server), notice: 'Server created'
    else
      load_index
      flash.now[:error] = 'Something went wrong. Please try again'
      return render :index
    end
  end

  def show
    @server = find_minecraft_server(params[:id])
    if @server.is_owner?(current_user) || @server.is_friend?(current_user)
    else
      raise ActionController::RoutingError.new('Not found')
    end
  end

  def start
    @server = find_minecraft_server(params[:id])
    error = @server.start
    if error
      flash_message = "Unable to start server: #{error}"
    else
      flash_message = 'Server starting'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def stop
    @server = find_minecraft_server(params[:id])
    error = @server.stop
    if error
      flash_message = "Unable to stop server: #{error}"
    else
      flash_message = 'Server is stopping'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def resume
    @server = find_minecraft_server(params[:id])
    if @server.resume
      flash_message = 'Server resumed'
    else
      flash_message = 'Unable to resume server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def pause
    @server = find_minecraft_server(params[:id])
    if @server.pause
      flash_message = 'Server paused'
    else
      flash_message = 'Unable to pause server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def backup
    @server = find_minecraft_server(params[:id])
    if @server.backup
      flash_message = 'World backed up locally on your droplet'
    else
      flash_message = 'Unable to backup server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def download
    @server = find_minecraft_server(params[:id])
    return redirect_to @server.world_download_url
  end

  def edit
  end

  def update_minecraft_properties
    @server = find_minecraft_server_only_owner(params[:id])
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
    @server = find_minecraft_server_only_owner(params[:id])
    if !@server.is_owner?(current_user)
      return redirect_to minecraft_server_path(@server), flash: {
        error: 'Only the owner can destroy a server.'
      }
    end
    error = @server.destroy_remote
    if error
      return redirect_to minecraft_server_path(@server), notice: "Unable to delete server: #{error}"
    end
    @server.destroy
    return redirect_to minecraft_servers_path, notice: 'Server is deleting'
  end

  def reboot
    @server = find_minecraft_server(params[:id])
    error = @server.reboot
    if error
      flash_message = "Unable to reboot server: #{flash_message}"
    else
      flash_message = 'Server is rebooting'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def add_friend
    @server = find_minecraft_server_only_owner(params[:id])
    email = minecraft_server_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to minecraft_server_path(@server), flash: { error: "User #{email} does not exist" }
    end
    if @server.is_owner?(friend)
      return redirect_to minecraft_server_path(@server), notice: 'You are already the owner of the server'
    end
    if @server.is_friend?(friend)
      return redirect_to minecraft_server_path(@server), notice: "User #{email} is already on this server"
    end
    @server.friends << friend
    return redirect_to minecraft_server_path(@server), notice: "User #{email} added to the server"
  end

  def remove_friend
    @server = find_minecraft_server_only_owner(params[:id])
    email = minecraft_server_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to minecraft_server_path(@server), flash: { error: "User #{email} does not exist" }
    end
    @server.friends.destroy(friend)
    return redirect_to minecraft_server_path(@server), notice: "User #{email} removed from the server"
  end

  def update
    @server = find_minecraft_server_only_owner(params[:id])
    if @server.update_attributes(minecraft_server_advanced_params)
      return redirect_to minecraft_server_path(@server), notice: 'Server advanced configuration updated'
    end
    @server_advanced_tab = true
    flash.now[:error] = 'Something went wrong. Please try again'
    return render :show
  end

  def command
    @server = find_minecraft_server(params[:id])
    if !@server.game_running?
      return redirect_to minecraft_server_path(@server), notice: 'Minecraft isn\'t running'
    end
    command = minecraft_server_command_params[:data]
    success = @server.node.exec(command)
    if success
      return redirect_to minecraft_server_path(@server), notice: 'Command sent'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to send command to Minecraft server'
  end

  def find_minecraft_server(id)
    server = MinecraftServer.find(id)
    if server.is_owner?(current_user) || server.is_friend?(current_user)
      return server
    end
    return nil
  end

  def find_minecraft_server_only_owner(id)
    return current_user.minecraft_servers.find(id)
  end

  def minecraft_server_params
    return params.require(:minecraft_server).permit(:name, :digital_ocean_size_slug, :digital_ocean_region_slug)
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

  def minecraft_server_friend_params
    return params.require(:minecraft_server_friend).permit(:email)
  end

  def minecraft_server_advanced_params
    return params.require(:minecraft_server).permit(:saved_snapshot_id,
      :remote_setup_stage,
      :pending_operation,
      :digital_ocean_region_slug,
      :digital_ocean_size_slug,
      droplet_attributes: [:remote_id]
    )
  end

  def minecraft_server_command_params
    return params.require(:command).permit(:data)
  end
end
