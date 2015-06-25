class ServerRemote
  def initialize(server)
    @server = server
    @user = @server.user
    @con = @user.digital_ocean
  end

  def exists?
    return !@server.remote_id.nil?
  end

  def sync
    if @data.nil?
      @data = @con.droplet_show(@server.remote_id)
    end
    @data
  end

  def invalidate
    @data = nil
  end

  def error?
    exists? && sync.error?
  end

  def error
    error? ? sync : nil
  end

  def ip_address
    d = sync
    d.error? ? error : d.ipv4
  end

  def status
    d = sync
    d.error? ? error : d.status
  end

  def latest_snapshot_id
    d = sync
    d.error? ? error : d.snapshot_ids.last
  end

  def create
    ssh_key_id = @user.digital_ocean_gamocosm_ssh_key_id
    if ssh_key_id.error?
      return ssh_key_id
    end
    res = @con.droplet_create(@server.host_name, @server.remote_region_slug, @server.remote_size_slug, @server.remote_snapshot_id || Gamocosm::DIGITAL_OCEAN_BASE_IMAGE_SLUG, [ssh_key_id])
    if res.error?
      return res
    end
    @server.update_columns(remote_id: res.id)
    res = @con.droplet_action_list(res.id)
    if res.error?
      return res
    end
    return res.last
  end

  def shutdown
    @con.droplet_shutdown(@server.remote_id)
  end

  def reboot
    @con.droplet_reboot(@server.remote_id)
  end

  def power_on
    @con.droplet_power_on(@server.remote_id)
  end

  def destroy
    if !exists?
      return nil
    end
    res = @con.droplet_delete(@server.remote_id)
    if res.error?
      return res
    end
    @server.update_columns(remote_id: nil)
    return nil
  end

  def snapshot
    @con.droplet_snapshot(@server.remote_id, @server.host_name)
  end

  def destroy_saved_snapshot
    if @server.remote_snapshot_id.nil?
      return nil
    end
    res = @con.image_delete(@server.remote_snapshot_id)
    if res.error?
      if res.data.status == 404 && res.data.body['id'] == 'not_found'
        return nil
      end
      return "Error destroying snapshot on Digital Ocean: #{res}"
    end
    return nil
  end
end
