# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  minecraft_server_id :integer
#  remote_id           :integer
#  remote_size_id      :integer
#  remote_region_id    :integer
#  ip_address          :inet
#  remote_status       :string(255)
#  last_synced         :datetime
#  created_at          :datetime
#  updated_at          :datetime
#

class DigitalOcean::Droplet

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
      # TODO error
      return nil
    end
    response = connection.droplets.create({
      name: @local_droplet.host_name,
      size_id: @local_droplet.minecraft_server.digital_ocean_droplet_size_id,
      image_id: @local_droplet.minecraft_server.saved_snapshot_id || Gamocosm.digital_ocean_base_snapshot_id,
      region_id: 4, # TODO
      ssh_key_ids: "#{ssh_key_id}",
    })
    if response.status == 'OK'
      return response.droplet.event_id
    end
    Rails.logger.error "Response was #{response}" # TODO: error
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
    Rails.logger.error "Response was #{response}" # TODO: error
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
    Rails.logger.error "Response was #{response}" # TODO: error
    return nil
  end

end
