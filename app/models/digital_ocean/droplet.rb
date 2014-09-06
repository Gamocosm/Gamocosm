# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  remote_id           :integer
#  ip_address          :inet
#  remote_status       :string(255)
#  last_synced         :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  minecraft_server_id :uuid
#  remote_region_slug  :string(255)
#  remote_size_slug    :string(255)
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
      size: @local_droplet.minecraft_server.digital_ocean_size_slug,
      image: @local_droplet.minecraft_server.saved_snapshot_id || Gamocosm.digital_ocean_base_snapshot_id,
      region: @local_droplet.minecraft_server.digital_ocean_region_slug,
      ssh_keys: [ssh_key_id.to_s],
    }
    response = connection.droplet.create(params)
    if response.success?
      @local_droplet.update_columns(remote_id: response.droplet.id)
      response = connection.droplet.actions(response.droplet.id)
      if response.success?
        return response.actions[-1].id
      end
      Rails.logger.error "DO::Droplet#create: response #{response}, params #{params}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    end
    Rails.logger.error "DO::Droplet#create: response #{response}, params #{params}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def shutdown
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplet.shutdown(@local_droplet.remote_id)
    if response.success?
      return response.action.id
    end
    Rails.logger.warn "DO::Droplet#shutdown: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def snapshot
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplet.snapshot(@local_droplet.remote_id, name: @local_droplet.host_name)
    if response.success?
      return response.action.id
    end
    Rails.logger.warn "DO::Droplet#snapshot: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def sync
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return false
    end
    response = connection.droplet.show(@local_droplet.remote_id)
    if response.success?
      @local_droplet.update_columns({
        remote_size_slug: response.droplet.size!.slug,
        remote_region_slug: response.droplet.region.slug,
        ip_address: response.droplet.networks.v4[0].ip_address,
        remote_status: response.droplet.status,
        last_synced: DateTime.now
      })
      return true
    end
    Rails.logger.warn "DO::Droplet#sync: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return false
  end

  def reboot
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplet.reboot(@local_droplet.remote_id)
    if !response.success?
      return nil
    end
    return response.action.id
  end

  # having snapshot and snapshots is asking for badness
  # #<Barge::Response meta=#<Hashie::Mash total=1> snapshots=[#<Hashie::Mash action_ids=[31352159] created_at="2014-08-25T04:51:40Z" distribution="Ubuntu" id=5766844 name="foo" public=false regions=["nyc2"] slug=nil>]>
  def list_snapshots
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return nil
    end
    response = connection.droplet.snapshots(@local_droplet.remote_id)
    if response.success?
      return response.snapshots
    end
    Rails.logger.warn "DO::Droplet#list_snapshots: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return nil
  end

  def destroy
    connection = @local_droplet.minecraft_server.user.digital_ocean
    if connection.nil?
      return false
    end
    snapshots = list_snapshots
    if snapshots.nil?
      return false
    end
    snapshots.each do |x|
      connection.image.destroy(x.id)
    end
    response = connection.droplet.destroy(@local_droplet.remote_id)
    if response.success?
      return true
    end
    Rails.logger.warn "DO::Droplet#destroy: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return false
  end

end
