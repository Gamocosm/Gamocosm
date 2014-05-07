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
    return redirect_to minecraft_server_path(@server), notice: 'Hmmmm'
  end

  def edit
  end

  def update
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.update_attributes(params.require(:minecraft_server).permit(:name)) # TODO hmmm
      return redirect_to minecraft_server_path(@server), notice: 'Server updated'
    end
    return redirect_to minecraft_server_path(@server), error: 'Unable to update server'
  end

  def destroy
    @server = current_user.minecraft_servers.find(params[:id])
    @server.update_columns(should_destroy: true)
    if @server.stop
      return redirect_to minecraft_servers_path, notice: 'Server is deleting'
    end
    return redirect_to minecraft_server_path(@server), notice: 'Unable to delete server'
  end

  def minecraft_server_params
    return params.require(:minecraft_server).permit(:name, :digital_ocean_droplet_size_id)
  end
end
