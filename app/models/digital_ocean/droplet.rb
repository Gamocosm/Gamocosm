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
    user = local_droplet.minecraft_server.user
    connection = user.digital_ocean
    if connection.nil?
      return nil
    end
    if user.minecraft_snapshot_id.nil?
      return nil
    end
    response = connection.droplets.create({
      name: local_droplet.host_name,
      size_id: local_droplet.minecraft_server.digital_ocean_droplet_size_id,
      image_id: user.minecraft_snapshot_id,
      region_id: 4, # TODO
    })
    if response.status == 'OK'
      return response
    end
    return nil
  end

  def shutdown
    connection = local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplets.shutdown(local_droplet.remote_id)
    if response.status == 'OK'
      return response.event_id
    end
    return nil
  end

  def snapshot
    connection = local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplets.snapshot(local_droplet.remote_id, name: local_droplet.host_name)
    if response.status == 'OK'
      return response.event_id
    end
    return nil
  end

end
