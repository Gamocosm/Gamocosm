class Volume < ApplicationRecord
  belongs_to :user

  validates :remote_size_gb, numericality: { only_integer: true }, allow_nil: false
  validates :remote_region_slug, presence: true

  after_initialize :after_initialize_callback
  before_validation :before_validation_callback

  def after_initialize_callback
    self.name ||= SecureRandom.hex(16)
  end

  def before_validation_callback
    self.remote_id = self.remote_id.clean
    self.remote_snapshot_id = self.remote_snapshot_id.clean
  end

  def remote
    if self.remote_id.nil?
      return nil
    end
    if @remote.nil?
      @remote = self.user.digital_ocean.volume_show(self.remote_id)
    end
    return @remote
  end

  def remote_snapshot
    if self.remote_snapshot_id.nil?
      return nil
    end
    if @remote_snapshot.nil?
      @remote_snapshot = self.user.digital_ocean.snapshot_show(self.remote_snapshot_id)
    end
    return @remote_snapshot
  end
end
