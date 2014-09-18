# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  remote_id           :integer
#  created_at          :datetime
#  updated_at          :datetime
#  minecraft_server_id :uuid
#

class DigitalOcean::Droplet
  include HTTParty

  def initialize(local_droplet)
    @local_droplet = local_droplet
    @connection = local_droplet.minecraft_server.user.digital_ocean
  end

  def ip_address
    data = self.sync
    return data.try(:droplet).try(:networks).try(:v4).try(:[], 0).try(:ip_address)
  end

  def status
    data = self.sync
    return data.try(:droplet).try(:status)
  end

  def busy?
    data = self.sync
    return data.try(:droplet).try(:locked)
  end

  def error
    data = self.sync
    if data.success?
      return nil
    end
    return data
  end

  def action_id
    if @actions_data.nil?
      @actions_data = @connection.droplet.actions(@local_droplet.remote_id)
    end
    if @actions_data.success?
      return @actions_data.actions[0].id
    end
    return nil
  end

  def event
    if action_id.nil?
      return nil
    end
    return DigitalOcean::DropletAction.new(@local_droplet.remote_id, action_id, @local_droplet.minecraft_server.user)
  end

  def create
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    ssh_key_id = @local_droplet.minecraft_server.user.digital_ocean_gamocosm_ssh_key_id
    if ssh_key_id.nil?
      Rails.logger.warn "DO::Droplet#create: ssh key id was null, user #{user.id}"
      return 'Unable to get gamocosm ssh key id'
    end
    params = {
      name: @local_droplet.host_name,
      size: @local_droplet.minecraft_server.digital_ocean_size_slug,
      image: @local_droplet.minecraft_server.saved_snapshot_id || Gamocosm.digital_ocean_base_snapshot_id,
      region: @local_droplet.minecraft_server.digital_ocean_region_slug,
      ssh_keys: [ssh_key_id.to_s],
    }
    response = @connection.droplet.create(params)
    if response.success?
      @local_droplet.update_columns(remote_id: response.droplet.id)
      return nil
    end
    Rails.logger.error "DO::Droplet#create: response #{response}, params #{params}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return "Error creating droplet on Digital Ocean; they responded with #{response}"
  end

  def shutdown
    if @connection.nil?
      return 'Digital Ocean API Token missing'
    end
    response = @connection.droplet.shutdown(@local_droplet.remote_id)
    if response.success?
      return nil
    end
    Rails.logger.warn "DO::Droplet#shutdown: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return "Error shutting down droplet on Digital Ocean; they responded with #{response}"
  end

  def snapshot
    if @connection.nil?
      return 'Digital Ocean API Token missing'
    end
    response = @connection.droplet.snapshot(@local_droplet.remote_id, name: @local_droplet.host_name)
    if response.success?
      @snapshot_action_id = response.action.id
      return nil
    end
    Rails.logger.warn "DO::Droplet#snapshot: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return "Error snapshotting droplet on Digital Ocean; they responded with #{response}"
  end

  def snapshot_action_id
    return @snapshot_action_id
  end

  def sync
    if @remote_data.nil?
      if @connection
        @remote_data = @connection.droplet.show(@local_droplet.remote_id)
      end
    end
    return @remote_data
  end

  def reboot
    if @connection.nil?
      return 'Digital Ocean API Token missing'
    end
    response = @connection.droplet.reboot(@local_droplet.remote_id)
    if response.success?
      return nil
    end
    Rails.logger.warn "DO::Droplet#reboot: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return "Error rebooting droplet on Digital Ocean; they responded with #{response}"
  end

  # having snapshot and snapshots is asking for badness
  # #<Barge::Response meta=#<Hashie::Mash total=1> snapshots=[#<Hashie::Mash action_ids=[31352159] created_at="2014-08-25T04:51:40Z" distribution="Ubuntu" id=5766844 name="foo" public=false regions=["nyc2"] slug=nil>]>
  def list_snapshots
    data = self.sync
    return data.try(:droplet).try(:snapshot_ids).try(:sort)
  end

  def destroy
    if @connection.nil?
      return 'Digital Ocean API Token missing'
    end
    response = @connection.droplet.destroy(@local_droplet.remote_id)
    if response.success? || response.id == 'not_found'
      @local_droplet.update_columns(remote_id: nil)
      return nil
    end
    Rails.logger.warn "DO::Droplet#destroy: response #{response}, MC #{@local_droplet.minecraft_server_id}, droplet #{@local_droplet.id}"
    return "Error destroying droplet on Digital Ocean; they responded with #{response}"
  end

end
