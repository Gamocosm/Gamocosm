class Volume < ApplicationRecord
  belongs_to :user
  belongs_to :server, optional: :true

  validates :name, length: { in: 3...32 }
  validates :name, format: { with: /\A[a-z][a-z0-9-]*[a-z0-9]\z/, message: 'Name must start with a letter, and end with a letter or number. May include letters, numbers, and dashes in between. Must be lower case' }
  validates :status, inclusion: { in: %w(volume snapshot), message: '%{value} is not a valid status' }
  validates :remote_size_gb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: false
  validates :remote_region_slug, presence: true

  after_initialize :after_initialize_callback
  before_validation :before_validation_callback

  def after_initialize_callback
    self.status ||= 'volume'
  end

  def before_validation_callback
    self.server_id = self.server_id.clean
    self.remote_id = self.remote_id.clean
    if self.remote_id.nil?
      self.status = 'volume'
    end
  end

  def volume?
    return self.status == 'volume'
  end

  def snapshot?
    return self.status == 'snapshot'
  end

  def remote_exists?
    return !self.remote_id.nil?
  end

  def remote
    if !self.volume?
      raise 'Badness'
    end
    if self.remote_id.nil?
      return nil
    end
    if @remote.nil?
      @remote = self.user.digital_ocean.volume_show(self.remote_id)
    end
    return @remote
  end

  def remote_snapshot
    if !self.snapshot?
      raise 'Badness'
    end
    if self.remote_id.nil?
      return nil
    end
    if @remote_snapshot.nil?
      @remote_snapshot = self.user.digital_ocean.snapshot_show(self.remote_id)
    end
    return @remote_snapshot
  end

  def vivify!
    if self.remote_id.nil?
      res = self.user.digital_ocean.volume_create(self.do_name, self.remote_size_gb, self.remote_region_slug, nil)
      if res.error?
        return res
      end
      self.update_columns(status: 'volume', remote_id: res.id)
      return nil
    end
    if self.volume?
      return nil
    end
    if self.snapshot?
      res = self.user.digital_ocean.volume_create(self.do_name, self.remote_size_gb, self.remote_region_slug, self.remote_id)
      if res.error?
        return res
      end
      self.update_columns(status: 'volume', remote_id: res.id)
      return nil
    end
    raise 'Badness'
  end

  def suspend?
    if self.remote_id.nil?
      return 'Volume has not been created yet.'
    end
    if self.snapshot?
      return 'Volume is already a snapshot.'
    end
    return nil
  end

  def reload?
    if self.remote_id.nil?
      return 'Volume has not been created yet.'
    end
    if self.volume?
      return 'Volume is already active.'
    end
    return nil
  end

  def suspend!
    error = self.suspend?
    if !error.nil?
      return error.error! nil
    end
    volume_id = self.remote_id
    res = self.user.digital_ocean.volume_snapshot(volume_id, self.do_name)
    if res.error?
      return res
    end
    self.update_columns(status: 'snapshot', remote_id: res.id)
    res = self.user.digital_ocean.volume_delete(volume_id)
    if res.error?
      return res
    end
    return nil
  end

  def reload!
    error = self.reload?
    if !error.nil?
      return error.error! nil
    end
    snapshot_id = self.remote_id
    res = self.user.digital_ocean.volume_create(self.do_name, self.remote_size_gb, self.remote_region_slug, snapshot_id)
    if res.error?
      return res
    end
    self.update_columns(status: 'volume', remote_id: res.id)
    res = self.user.digital_ocean.snapshot_delete(snapshot_id)
    if res.error?
      return res
    end
    return nil
  end

  def remote_delete
    if self.remote_id.nil?
      return nil
    end
    if self.volume?
      res = self.user.digital_ocean.volume_delete(self.remote_id)
      if res.error?
        return res
      end
      self.update_columns(status: 'volume', remote_id: nil)
      return nil
    end
    if self.snapshot?
      res = self.user.digital_ocean.snapshot_delete(self.remote_id)
      if res.error?
        return res
      end
      self.update_columns(status: 'volume', remote_id: nil)
      return nil
    end
    raise 'Badness'
  end

  def do_name
    return 'gamocosm-' + self.name
  end

  def mount_path
    return "/mnt/#{self.do_name.gsub('-', '_')}"
  end

  def device_path
    return "/dev/disk/by-id/scsi-0DO_Volume_#{self.do_name}"
  end
end
