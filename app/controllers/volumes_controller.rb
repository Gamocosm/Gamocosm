class VolumesController < ApplicationController
  before_action :set_volume, only: [:show, :edit, :update, :destroy, :delete, :suspend, :reload]
  before_action :authenticate_user!

  # GET /volumes
  # GET /volumes.json
  def index
    @volumes = Volume.all
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
    @volume = current_user.volumes.create(volume_params)

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
      if @volume.update(volume_params)
        format.html { redirect_to @volume, notice: 'Volume was successfully updated.' }
        format.json { render :show, status: :ok, location: @volume }
      else
        @do_regions = Gamocosm.digital_ocean.region_list
        format.html { render :edit }
        format.json { render json: @volume.errors, status: :unprocessable_entity }
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
    error = @volume.save!
    f = { success: 'Volume has been suspended' }
    if error.error?
      f = { error: error.msg }
    end
    return redirect_to volume_path(@volume), flash: f
  end

  def reload
    error = @volume.load!
    f = { success: 'Volume has been reloaded' }
    if error.error?
      f = { error: error.msg }
    end
    return redirect_to volume_path(@volume), flash: f
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
