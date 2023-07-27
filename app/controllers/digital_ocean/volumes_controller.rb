class DigitalOcean::VolumesController < ApplicationController
  before_action :authenticate_user!
  layout false

  def index
    @do_volumes = current_user.digital_ocean_volumes
  end

  def destroy
    error = current_user.digital_ocean.volume_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_volumes
    if error
      return redirect_to volumes_path, flash: { error: }
    end
    redirect_to volumes_path, flash: { notice: 'Deleted volume on Digital Ocean' }
  end
end
