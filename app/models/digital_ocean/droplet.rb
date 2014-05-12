# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  remote_id           :integer
#  remote_size_id      :integer
#  remote_region_id    :integer
#  ip_address          :inet
#  remote_status       :string(255)
#  last_synced         :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  minecraft_server_id :uuid
#

class DigitalOcean::Droplet
  include HTTParty

  def initialize(local_droplet)
    @local_droplet = local_droplet
  end

  def create
    user = @local_droplet.minecraft_server.user
    connection = user.digital_ocean
    if connection.nil?
      return nil
    end
    ssh_key_id = user.digital_ocean_gamocosm_ssh_key_id
    if ssh_key_id.nil?
      Rails.logger.warn "DO::Droplet#create: ssh key id was null, user #{user.id}"
      return nil
    end
    params = {
      name: @local_droplet.host_name,
      size_id: @local_droplet.minecraft_server.digital_ocean_droplet_size_id,
      image_id: @local_droplet.minecraft_server.saved_snapshot_id || Gamocosm.digital_ocean_base_snapshot_id,
      region_id: @local_droplet.minecraft_server.digital_ocean_droplet_region_id,
      ssh_key_ids: "#{ssh_key_id}",
    }
    response = connection.droplets.create(params)
    if response.status == 'OK'
      return response.droplet.event_id
    end
    Rails.logger.error "DO::Droplet#create: response #{response}, params #{params}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def shutdown
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplets.shutdown(@local_droplet.remote_id)
    if response.status == 'OK'
      return response.event_id
    end
    Rails.logger.warn "DO::Droplet#shutdown: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def snapshot
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplets.snapshot(@local_droplet.remote_id, name: @local_droplet.host_name)
    if response.status == 'OK'
      return response.event_id
    end
    Rails.logger.warn "DO::Droplet#snapshot: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def sync
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return false
    end
    response = connection.droplets.show(@local_droplet.remote_id)
    if response.status == 'OK'
      @local_droplet.update_columns({
        remote_size_id: response.droplet.size_id,
        remote_region_id: response.droplet.region_id,
        ip_address: response.droplet.ip_address,
        remote_status: response.droplet.status,
        last_synced: DateTime.now
      })
      return true
    end
    Rails.logger.warn "DO::Droplet#sync: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return false
  end

  # having snapshot and snapshots is asking for badness
  def list_snapshots
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplets.show(@local_droplet.remote_id)
    if response.status == 'OK'
      return response.droplet.snapshots
    end
    Rails.logger.warn "DO::Droplet#list_snapshots: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def destroy
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return false
    end
    list_snapshots.each do |x|
      connection.images.delete(x.id)
    end
    response = connection.droplets.delete(@local_droplet.remote_id)
    if response.status == 'OK'
      return true
    end
    Rails.logger.warn "DO::Droplet#destroy: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return false
  end

  def rename
    user = @local_droplet.minecraft_server.user
    if user.missing_digital_ocean?
      return false
    end
    response = self.class.get("https://api.digitalocean.com/droplets/#{@local_droplet.remote_id}/?client_id=#{user.digital_ocean_client_id}&api_key=#{user.digital_ocean_api_key}&name=gamocosm-minecraft-#{@local_droplet.minecraft_server.name}")
    body = JSON.parse(response.body)
    return !body.nil? && body['status'] == 'OK'
  end

end
