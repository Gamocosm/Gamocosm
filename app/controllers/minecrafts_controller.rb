class MinecraftsController < ApplicationController
  before_action :authenticate_user!

  def load_index
    @do_droplets = current_user.digital_ocean_droplets
    @do_snapshots = current_user.digital_ocean_snapshots
    @friend_minecrafts = current_user.friend_minecrafts
  end

  def index
    @minecraft = Minecraft.new
    @minecraft.server = Server.new
    @minecrafts = current_user.minecrafts
    load_index
  end

  def new
  end

  def create
    begin
      @minecraft = current_user.minecrafts.create!(minecraft_params)
      return redirect_to minecraft_path(@minecraft), notice: 'You made a new server! Start it to play'
    rescue
      load_index
      @minecrafts = current_user.minecrafts.reload
      flash.now[:error] = 'Something went wrong. Please try again'
      return render :index
    end
  end

  def show
    @minecraft = find_minecraft(params[:id])
  end

  def start
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.start
    if error
      flash_message = "Unable to start server: #{error}"
    else
      flash_message = 'Server starting'
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def stop
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.stop
    if error
      flash_message = "Unable to stop server: #{error}"
    else
      flash_message = 'Server is stopping'
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def resume
    @minecraft = find_minecraft(params[:id])
    if @minecraft.server.remote.error?
      flash_message = "Error with Digital Ocean droplet: #{@minecraft.server.remote.error}"
    elsif !@minecraft.server.running?
      flash_message = 'Minecraft server not running'
    else
      error = @minecraft.node.resume
      if error
        flash_message = "Unable to resume server: #{error}"
      else
        flash_message = 'Server resumed'
      end
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def pause
    @minecraft = find_minecraft(params[:id])
    if @minecraft.server.remote.error?
      flash_message = "Error with Digital Ocean droplet: #{@minecraft.server.remote.error}"
    elsif !@minecraft.server.running?
      flash_message = 'Minecraft server not running'
    else
      error = @minecraft.node.pause
      if error
        flash_message = "Unable to pause server: #{error}"
      else
        flash_message = 'Server paused'
      end
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def backup
    @minecraft = find_minecraft(params[:id])
    if @minecraft.server.remote.error?
      flash_message = "Error with Digital Ocean droplet: #{@minecraft.server.remote.error}"
    elsif !@minecraft.server.running?
      flash_message = 'Minecraft server not running'
    else
      error = @minecraft.node.backup
      if error
        flash_message = "Unable to backup server: #{error}"
      else
        flash_message = 'Unable to backup server'
      end
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def download
    @minecraft = find_minecraft(params[:id])
    if @minecraft.server.remote.error?
      flash_message = "Error with Digital Ocean droplet: #{@minecraft.server.remote.error}"
    elsif !@minecraft.server.running?
      flash_message = 'Minecraft server not running'
    else
      return redirect_to @minecraft.world_download_url
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def edit
  end

  def update_minecraft_properties
    @minecraft = find_minecraft_only_owner(params[:id])
    if @minecraft.server.remote.error?
      flash_message = "Error with Digital Ocean droplet: #{@minecraft.server.remote.error}"
    elsif !@minecraft.server.running?
      flash_message = 'Minecraft server not running. Start it to edit properties'
    end
    if flash_message
      return redirect_to minecraft_path(@minecraft), error: flash_message
    end
    properties = @minecraft.properties
    if properties.update(minecraft_properties_params)
      return redirect_to minecraft_path(@minecraft), notice: 'Minecraft properties updated'
    end
    return redirect_to minecraft_path(@minecraft), notice: 'Unable to update Minecraft properties'
  end

  def destroy
    @minecraft = find_minecraft(params[:id])
    if !@minecraft.is_owner?(current_user)
      return redirect_to minecraft_path(@minecraft), flash: {
        error: 'Only the owner can destroy a server.'
      }
    end
    if !@minecraft.server.remote.exists?
      return redirect_to minecraft_path(@minecraft), notice: 'Remote server does not exist'
    end
    error = @minecraft.server.remote.destroy
    if error
      return redirect_to minecraft_path(@minecraft), notice: "Unable to delete server: #{error}"
    end
    @minecraft.destroy
    return redirect_to minecrafts_path, notice: 'Server is deleting'
  end

  def update
    @minecraft = find_minecraft_only_owner(params[:id])
    if @minecraft.update_attributes(minecraft_advanced_params)
      return redirect_to minecraft_path(@minecraft), notice: 'Server advanced configuration updated'
    end
    @minecraft_advanced_tab = true
    flash.now[:error] = 'Something went wrong. Please try again'
    return render :show
  end

  def command
    @minecraft = find_minecraft(params[:id])
    if @minecraft.server.remote.error?
      flash_message = "Error with Digital Ocean droplet: #{@minecraft.server.remote.error}"
    elsif !@minecraft.server.running?
      flash_message = 'Minecraft server not running. Start it to edit properties'
    elsif !@minecraft.running?
      flash_message = 'Minecraft isn\'t running'
    end
    if flash_message
      return redirect_to minecraft_path(@minecraft), notice: 'Minecraft isn\'t running'
    end
    command = minecraft_command_params[:data]
    error = @minecraft.node.exec(command)
    if error
    return redirect_to minecraft_path(@minecraft), notice: "Unable to send command to Minecraft server: #{error}"
    end
    return redirect_to minecraft_path(@minecraft), notice: 'Command sent'
  end

  def reboot
    @minecraft = find_minecraft(params[:id])
    error = @minecraft.reboot
    if error
      flash_message = "Unable to reboot server: #{flash_message}"
    else
      flash_message = 'Server is rebooting'
    end
    return redirect_to minecraft_path(@minecraft), notice: flash_message
  end

  def add_friend
    @minecraft = find_minecraft_only_owner(params[:id])
    email = minecraft_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to minecraft_path(@minecraft), flash: { error: "User #{email} does not exist" }
    end
    if @minecraft.is_owner?(friend)
      return redirect_to minecraft_path(@minecraft), notice: 'You are already the owner of the server'
    end
    if @minecraft.is_friend?(friend)
      return redirect_to minecraft_path(@minecraft), notice: "User #{email} is already on this server"
    end
    @minecraft.friends << friend
    return redirect_to minecraft_path(@minecraft), notice: "User #{email} added to the server"
  end

  def remove_friend
    @minecraft = find_minecraft_only_owner(params[:id])
    email = minecraft_friend_params[:email]
    friend = User.find_by_email(email)
    if friend.nil?
      return redirect_to minecraft_path(@minecraft), flash: { error: "User #{email} does not exist" }
    end
    @minecraft.friends.destroy(friend)
    return redirect_to minecraft_path(@minecraft), notice: "User #{email} removed from the server"
  end

  def find_minecraft(id)
    begin
      server = Minecraft.find(id)
    rescue
      raise ActionController::RoutingError.new('Not found')
    end
    if server.is_owner?(current_user) || server.is_friend?(current_user)
      return server
    end
    raise ActionController::RoutingError.new('Not found')
  end

  def find_minecraft_only_owner(id)
    begin
      return current_user.minecrafts.find(id)
    rescue
    end
    raise ActionController::RoutingError.new('Not found')
  end

  def minecraft_params
    return params.require(:minecraft).permit(:name, server_attributes: [:do_region_slug, :do_size_slug])
  end

  def minecraft_properties_params
    return params.require(:minecraft_properties).permit(:allow_flight,
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

  def minecraft_friend_params
    return params.require(:minecraft_friend).permit(:email)
  end

  def minecraft_advanced_params
    return params.require(:minecraft).permit(server_attributes: [
      :remote_setup_stage,
      :pending_operation,
      :do_saved_snapshot_id,
      :do_region_slug,
      :do_size_slug
    ])
  end

  def minecraft_command_params
    return params.require(:command).permit(:data)
  end
end
