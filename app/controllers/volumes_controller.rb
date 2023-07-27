class VolumesController < ApplicationController
  before_action :set_volume, only: [:show, :edit, :update, :destroy, :delete, :suspend, :reload]
  before_action :authenticate_user!

  def index
    @volumes = current_user.volumes
  end

  def show; end

  def new
    @volume = Volume.new
    @do_regions = Gamocosm.digital_ocean.region_list
  end

  def create
    begin
      @volume = current_user.volumes.create(volume_params)
    rescue ActiveRecord::RecordNotUnique
      @volume = Volume.new(volume_params)
      @do_regions = Gamocosm.digital_ocean.region_list
      flash[:error] = 'The server you selected already has a volume.'
      return render :new
    end

    if @volume.save
      redirect_to @volume, notice: 'Volume was successfully created.'
    else
      @do_regions = Gamocosm.digital_ocean.region_list
      render :new
    end
  end

  def edit
    @do_regions = Gamocosm.digital_ocean.region_list
  end

  def update
    begin
      if @volume.update(volume_params)
        redirect_to @volume, notice: 'Volume was successfully updated.'
      else
        @do_regions = Gamocosm.digital_ocean.region_list
        render :edit
      end
    rescue ActiveRecord::RecordNotUnique
      @do_regions = Gamocosm.digital_ocean.region_list
      flash[:error] = 'The server you selected already has a volume.'
      render :edit
    end
  end

  def destroy
    if !@volume.server.nil?
      return redirect_to volume_path(@volume), flash: { error: "This volume is attached to server #{@volume.server.name}" }
    end
    error = @volume.remote_delete
    @volume.user.invalidate_digital_ocean_cache_volumes
    @volume.user.invalidate_digital_ocean_cache_snapshots
    if error?
      return redirect_to volume_path(@volume), flash: { error: "Error deleting volume on Digital Ocean: #{error}" }
    end
    @volume.destroy
    redirect_to volumes_url, notice: 'Volume was successfully destroyed.'
  end

  def confirm_delete
    render :confirm_delete
  end

  def suspend
    error = @volume.suspend!
    f = { success: 'Volume has been suspended' }
    if error.error?
      f = { error: error.msg }
    end
    @volume.user.invalidate_digital_ocean_cache_volumes
    @volume.user.invalidate_digital_ocean_cache_snapshots
    redirect_to volume_path(@volume), flash: f
  end

  def reload
    error = @volume.reload!
    f = { success: 'Volume has been reloaded' }
    if error.error?
      f = { error: error.msg }
    end
    @volume.user.invalidate_digital_ocean_cache_volumes
    @volume.user.invalidate_digital_ocean_cache_snapshots
    redirect_to volume_path(@volume), flash: f
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_volume
    @volume = Volume.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def volume_params
    params.require(:volume).permit(:name, :status, :remote_id, :remote_size_gb, :remote_region_slug, :server_id)
  end
end
