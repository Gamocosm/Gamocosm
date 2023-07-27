class DigitalOcean::ImagesController < ApplicationController
  before_action :authenticate_user!
  layout false

  def index
    @do_images = current_user.digital_ocean_images
  end

  def destroy
    error = current_user.digital_ocean.image_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_images
    if error
      return redirect_to servers_path, flash: { error: }
    end
    redirect_to servers_path, flash: { notice: 'Deleted snapshot on Digital Ocean' }
  end
end
