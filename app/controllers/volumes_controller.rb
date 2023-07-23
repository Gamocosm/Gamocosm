class VolumesController < ApplicationController
  before_action :set_volume, only: [:show, :edit, :update, :destroy, :delete, :suspend, :reload]
  before_action :authenticate_user!

  # GET /volumes
  # GET /volumes.json
  def index
    @volumes = current_user.volumes
  end

  # GET /volumes/1
  # GET /volumes/1.json
  def show
  end

  # GET /volumes/new
  def new
    @volume = Volume.new
    @do_regions = Gamocosm.digital_ocean.region_list
  end

  # GET /volumes/1/edit
  def edit
    @do_regions = Gamocosm.digital_ocean.region_list
  end

  # POST /volumes
  # POST /volumes.json
  def create
    begin
      @volume = current_user.volumes.create(volume_params)
    rescue ActiveRecord::RecordNotUnique
      @volume = Volume.new(volume_params)
      @do_regions = Gamocosm.digital_ocean.region_list
      flash[:error] = 'The server you selected already has a volume.'
      return render :new
    end

    respond_to do |format|
      if @volume.save
        format.html { redirect_to @volume, notice: 'Volume was successfully created.' }
        format.json { render :show, status: :created, location: @volume }
      else
        @do_regions = Gamocosm.digital_ocean.region_list
        format.html { render :new }
        format.json { render json: @volume.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /volumes/1
  # PATCH/PUT /volumes/1.json
  def update
    respond_to do |format|
      begin
        if @volume.update(volume_params)
          format.html { redirect_to @volume, notice: 'Volume was successfully updated.' }
          format.json { render :show, status: :ok, location: @volume }
        else
          @do_regions = Gamocosm.digital_ocean.region_list
          format.html { render :edit }
          format.json { render json: @volume.errors, status: :unprocessable_entity }
        end
      rescue ActiveRecord::RecordNotUnique
        @do_regions = Gamocosm.digital_ocean.region_list
        flash[:error] = 'The server you selected already has a volume.'
        return render :edit
      end
    end
  end

  # DELETE /volumes/1
  # DELETE /volumes/1.json
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
    respond_to do |format|
      format.html { redirect_to volumes_url, notice: 'Volume was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def delete
    render :delete
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

  def show_digital_ocean_volumes
    @do_volumes = current_user.digital_ocean_volumes
    render layout: nil
  end

  def destroy_digital_ocean_volume
    error = current_user.digital_ocean.volume_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_volumes
    if error
      return redirect_to volumes_path, flash: { error: }
    end
    redirect_to volumes_path, flash: { notice: 'Deleted volume on Digital Ocean' }
  end

  def show_digital_ocean_snapshots
    @do_snapshots = current_user.digital_ocean_snapshots
    render layout: nil
  end

  def destroy_digital_ocean_snapshot
    error = current_user.digital_ocean.snapshot_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_snapshots
    if error
      return redirect_to volumes_path, flash: { error: }
    end
    redirect_to volumes_path, flash: { notice: 'Deleted snapshot on Digital Ocean' }
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
