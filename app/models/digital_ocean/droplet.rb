class DigitalOcean::Droplet
  include HTTParty

  def initialize(server, connection)
    @server = server
    @connection = connection
  end

  def ip_address
    data = self.sync
    return data.try(:droplet).try(:networks).try(:v4).try(:select) { |x| x.type == 'public' }.try(:first).try(:ip_address)
  end

  def status
    data = self.sync
    return data.try(:droplet).try(:status)
  end

  def exists?
    return !@server.remote_id.nil?
  end

  # Should be unused
  def busy?
    data = self.sync
    return data.try(:droplet).try(:locked)
  end

  def error?
    if !exists?
      return false
    end
    return !error.nil?
  end

  def sync
    if @remote_data.nil?
      if @connection
        @remote_data = @connection.droplet.show(@server.remote_id)
      end
    end
    return @remote_data
  rescue => e
    ExceptionNotifier.notify_exception(e)
    e.define_singleton_method(:success?) { false }
    @remote_data = e.error!
    return @remote_data
  end

  def error
    data = self.sync
    if data.nil?
      return 'Digital Ocean API token missing'
    end
    if data.success?
      return nil
    end
    return data
  end

  def invalidate
    @remote_data = nil
    @action_id = nil
  end

  def action_id
    return @action_id
  end

  def latest_snapshot_id
    data = self.sync
    if data.success?
      return data.try(:droplet).try(:snapshot_ids).try(:sort).try(:[], -1)
    end
    return nil
  end

  def create
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    user = @server.minecraft.user
    ssh_key_id = user.digital_ocean_gamocosm_ssh_key_id
    if ssh_key_id.error?
      Rails.logger.warn "DO::Droplet#create: ssh key id was null, user #{user.id}"
      return "Unable to get gamocosm ssh key id: #{ssh_key_id}"
    end
    params = {
      name: @server.host_name,
      size: @server.do_size_slug,
      region: @server.do_region_slug,
      image: @server.do_saved_snapshot_id || Gamocosm::DIGITAL_OCEAN_BASE_IMAGE_SLUG,
      ssh_keys: [ssh_key_id.to_s],
    }
    @server.minecraft.user.invalidate
    response = @connection.droplet.create(params)
    if response.success?
      @server.update_columns(remote_id: response.droplet.id)
      response = @connection.droplet.actions(@server.remote_id)
      if !response.success?
        return "Created server on Digital Ocean, but unable to get action id to listen on; they responded with #{response}"
      end
      create_action_id = response.actions.first.id
      if create_action_id.nil?
        return "Created server on Digital Ocean, but latest action id null. List actions response was #{response}"
      end
      @action_id = create_action_id
      return nil
    end
    return "Error creating droplet on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error creating droplet on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

  def power_on
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    response = @connection.droplet.power_on(@server.remote_id)
    if response.success?
      @action_id = response.action.id
      return nil
    end
    return "Error powering on droplet on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error powering on droplet on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

  def shutdown
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    response = @connection.droplet.shutdown(@server.remote_id)
    if response.success?
      @action_id = response.action.id
      return nil
    end
    return "Error shutting down droplet on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error shutting down droplet on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

  def snapshot
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    response = @connection.droplet.snapshot(@server.remote_id, name: @server.host_name)
    if response.success?
      @action_id = response.action.id
      return nil
    end
    return "Error snapshotting droplet on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error snapshotting droplet on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

  def reboot
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    response = @connection.droplet.reboot(@server.remote_id)
    if response.success?
      @action_id = response.action.id
      return nil
    end
    return "Error rebooting droplet on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error rebooting droplet on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

  def destroy
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    if !exists?
      return nil
    end
    @server.minecraft.user.invalidate
    response = @connection.droplet.destroy(@server.remote_id)
    if response.success? || response.id == 'not_found'
      @server.update_columns(remote_id: nil)
      return nil
    end
    return "Error destroying droplet on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error destroying droplet on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

  def destroy_saved_snapshot
    if @connection.nil?
      return 'Digital Ocean API token missing'
    end
    if @server.do_saved_snapshot_id.nil?
      return nil
    end
    @server.minecraft.user.invalidate
    response = @connection.image.destroy(@server.do_saved_snapshot_id)
    if response.success? || response.id == 'not_found'
      @server.update_columns(do_saved_snapshot_id: nil)
      return nil
    end
    return "Error destroying snapshot on Digital Ocean; they responded with #{response}"
  rescue => e
    ExceptionNotifier.notify_exception(e)
    msg = "Error destroying snapshot on Digital Ocean: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    return msg
  end

end
