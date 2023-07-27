class DigitalOcean::DropletsController < ApplicationController
  before_action :authenticate_user!
  layout false

  def index
    @do_droplets = current_user.digital_ocean_droplets
  end

  def destroy
    error = current_user.digital_ocean.droplet_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_droplets
    if error
      return redirect_to servers_path, flash: { error: }
    end
    redirect_to servers_path, flash: { notice: 'Deleted droplet on Digital Ocean' }
  end
end
