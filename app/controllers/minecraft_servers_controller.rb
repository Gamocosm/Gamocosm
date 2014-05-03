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
      @server.create_droplet
      digital_ocean_droplet = DigitalOcean::Droplet.new(@server.droplet)
      response = digital_ocean_droplet.create
      if response.nil?
        # TODO: delete server?
        flash.now[:error] = 'Something went wrong. Please try again'
        return render :index
      end
      WaitForStartingServerWorker.perform_in(32.seconds, current_user.id, @server.droplet.id, response.droplet.event_id)
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
  end

  def stop
  end

  def resume
  end

  def pause
  end

  def edit
  end

  def update
    @server = current_user.minecraft_servers.find(params[:id])
    if @server.update_attributes(params.require(:minecraft_server).permit(:name))
      return redirect_to minecraft_server_path(@server), notice: 'Server updated'
    end
    flash.now[:error] = 'Unable to update server'
    return render :show
  end

  def destroy
    @server = current_user.minecraft_servers.find(params[:id])
    # TODO: destroy
  end

  def minecraft_server_params
    return params.require(:minecraft_server).permit(:name, :digital_ocean_droplet_size_id)
  end
end
