class MinecraftServersController < ApplicationController
  before_filter :authenticate_user!

  def index
    @servers = current_user.minecraft_servers
    @server = MinecraftServer.new
    @droplets = current_user.digital_ocean_droplets
    @snapshots = current_user.digital_ocean_snapshots
    @friend_minecraft_servers = current_user.friend_minecraft_servers
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
    @server = find_minecraft_server(params[:id])
    if @server.is_owner?(current_user) || @server.is_friend?(current_user)
    else
      raise ActionController::RoutingError.new('Not found')
    end
  end

  def start
    @server = find_minecraft_server(params[:id])
    if @server.user.missing_digital_ocean?
      if @server.is_owner?(current_user)
        return redirect_to minecraft_server_path(@server), flash: {
          error: "You have not entered your Digital Ocean keys.<br />Instructions/enter it #{view_context.link_to('here', edit_user_registration_path)}"
        }
      else
        return redirect_to minecraft_server_path(@server), flash: {
          error: "The owner of this server did not enter his/her Digital Ocean keys.<br />Read more #{view_context.link_to('here', edit_user_registration_path)}"
        }
      end
    end
    if @server.start
      flash_message = 'Server starting'
    else
      flash_message = 'Unable to start server'
    end
    return redirect_to minecraft_server_path(@server), notice: flash_message
  end

  def stop
    @server = find_minecraft_server(params[:id])
    if @server.user.missing_digital_ocean?
      if @server.is_owner?(current_user)
        return redirect_to minecraft_server_path(@server), flash: {
          error: "You have not entered your Digital Ocean keys.<br />Instructions/enter it #{view_context.link_to('here', edit_user_registration_path)}"
        }
      else
        return redirect_to minecraft_server_path(@server), flash: {
          error: "The owner of this server did not enter his/her Digital Ocean keys.<br />Read more #{view_context.link_to('here', edit_user_registration_path)}"
        }
      end
    end
    if @server.stop
      return redirect_to minecraft_servers_path, notice: 'Server is stopping'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to stop server'
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

  def update
    @server = find_minecraft_server_only_owner(params[:id])
    if @server.update_attributes(params.require(:minecraft_server).permit(:name))
      if @server.droplet_running?
        @server.droplet.remote.rename
      end
      return redirect_to minecraft_server_path(@server), notice: 'Server updated'
    end
    return redirect_to minecraft_server_path(@server), error: 'Unable to update server'
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
    if @server.user.missing_digital_ocean?
      if @server.is_owner?(current_user)
        return redirect_to minecraft_server_path(@server), flash: {
          error: "You have not entered your Digital Ocean keys.<br />Instructions/enter it #{view_context.link_to('here', edit_user_registration_path)}"
        }
      else
        return redirect_to minecraft_server_path(@server), flash: {
          error: "The owner of this server did not enter his/her Digital Ocean keys.<br />Read more #{view_context.link_to('here', edit_user_registration_path)}"
        }
      end
    end
    response = @server.droplet.remote.destroy
    if response
      @server.destroy
      return redirect_to minecraft_servers_path, notice: 'Server is deleting'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to delete server'
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
    return params.require(:minecraft_server).permit(:name, :digital_ocean_droplet_size_id, :digital_ocean_droplet_region_id)
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
end
