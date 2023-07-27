class DigitalOcean::SshKeysController < ApplicationController
  before_action :authenticate_user!
  layout false

  def index
    @do_ssh_keys = current_user.digital_ocean_ssh_keys
  end

  def create
    ssh_key_name = params[:digital_ocean_ssh_key][:name]
    ssh_public_key = params[:digital_ocean_ssh_key][:data]
    f = { success: 'Added SSH public key to Digital Ocean' }
    ssh_key = current_user.digital_ocean.ssh_key_create(ssh_key_name, ssh_public_key)
    if ssh_key.error?
      f = { error: ssh_key }
    end
    redirect_back fallback_location: servers_path, flash: f
  end

  def destroy
    error = current_user.digital_ocean.ssh_key_delete(params[:id])
    current_user.invalidate_digital_ocean_cache_ssh_keys
    f = { success: 'Deleted SSH public key from Digital Ocean' }
    if error
      f = { error: }
    end
    redirect_back fallback_location: servers_path, flash: f
  end
end
