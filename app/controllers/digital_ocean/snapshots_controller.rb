class DigitalOcean::SnapshotsController < ApplicationController
  before_action :authenticate_user!
  layout false

  def index
    @do_snapshots = current_user.digital_ocean_snapshots
  end

  def destroy
    error = current_user.digital_ocean.snapshot_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_snapshots
    if error
      return redirect_to volumes_path, flash: { error: }
    end
    redirect_to volumes_path, flash: { notice: 'Deleted snapshot on Digital Ocean' }
  end
end
