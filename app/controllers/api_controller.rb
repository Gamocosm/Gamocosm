class APIController < ApplicationController
  #skip_before_action :verify_authenticity_token
  before_action :find_server
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def status
    active = server.running?
    status = server.pending_operation
    minecraft = server.minecraft.running?
    ip = server.remote.exists? ? server.remote.ip_address : nil
    download = server.minecraft.world_download_url
    render json: {
      server: active,
      status:,
      minecraft:,
      ip:,
      domain: server.host_name,
      download:,
    }
  end

  def start
    err = @server.start
    @server.user.invalidate_digital_ocean_cache_droplets
    @server.user.invalidate_digital_ocean_cache_volumes
    @server.user.invalidate_digital_ocean_cache_snapshots
    render json: {
      error: err,
    }
  end

  def stop
    err = @server.stop
    render json: {
      error: err,
    }
  end

  def reboot
    err = @server.reboot
    render json: {
      error: err,
    }
  end

  def pause
    err = @server.minecraft.pause
    render json: {
      error: err,
    }
  end

  def resume
    err = @server.minecraft.resume
    render json: {
      error: err,
    }
  end

  def backup
    err = @server.minecraft.backup
    render json: {
      error: err,
    }
  end

  def exec
    err = @server.minecraft.exec(@server.user, params[:command])
    render json: {
      error: err,
    }
  end

  private
  def find_server
    @server = Server.find_by(id: params[:id], api_key: params[:key])
  end

  def not_found
    render json: {
      error: 'Not found',
    }, status: 404
  end
end
