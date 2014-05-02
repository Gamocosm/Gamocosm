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
      redirect_to minecraft_server_path(@server), notice: 'Server created'
    else
      flash.now[:error] = 'Something went wrong. Please try again'
      render :index
    end
  end

  def show
    @server = current_user.minecraft_servers.find(params[:id])
  end

  def edit
  end

  def update
  end

  def destroy
  end

  def minecraft_server_params
    return params.require(:minecraft_server).permit(:name, :digital_ocean_droplet_size_id)
  end
end
