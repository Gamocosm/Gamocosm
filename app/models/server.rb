# == Schema Information
#
# Table name: servers
#
#  id                   :integer          not null, primary key
#  remote_id            :integer
#  created_at           :datetime
#  updated_at           :datetime
#  minecraft_id         :uuid             not null
#  do_region_slug       :string(255)      not null
#  do_size_slug         :string(255)      not null
#  do_saved_snapshot_id :integer
#  remote_setup_stage   :integer          default(0), not null
#  pending_operation    :string(255)
#

class Server < ActiveRecord::Base
  belongs_to :minecraft

  validates :remote_id, numericality: { only_integer: true }, allow_nil: true
  validates :remote_setup_stage, numericality: { only_integer: true }
  validates :do_region_slug, presence: true
  validates :do_size_slug, presence: true

  before_validation :before_validate_callback

  def before_validate_callback
    self.remote_id = self.remote_id.blank? ? nil : self.remote_id
    self.pending_operation = self.pending_operation.blank? ? nil : self.pending_operation.strip.downcase
    self.do_saved_snapshot_id = self.do_saved_snapshot_id.blank? ? nil : self.do_saved_snapshot_id
    self.do_region_slug = self.do_region_slug.strip.downcase
    self.do_size_slug = self.do_size_slug.strip.downcase
  end

  def remote
    if @remote.nil?
      @remote = DigitalOcean::Droplet.new(self)
    end
    return @remote
  end

  def host_name
    return "gamocosm-minecraft-#{minecraft.name}"
  end

  def ram
    droplet_size = DigitalOcean::Size.new.find(do_size_slug)
    if droplet_size.nil?
      minecraft.log("Unknown Digital Ocean size slug #{do_size_slug}; only starting server with 512MB of RAM")
      return 512
    end
    return droplet_size[:memory]
  end

  def start?
    if remote.exists?
      return 'Server already started'
    end
    if busy?
      return 'Server is busy'
    end
    return nil
  end

  def stop?
    if !remote.exists?
      return 'Server already stopped'
    end
    if busy?
      return 'Server is busy'
    end
    return nil
  end

  def reboot?
    if !remote.exists?
      return 'Server not running'
    end
    if busy?
      return 'Server is busy'
    end
    return nil
  end

  def start
    error = remote.create
    if error
      return error
    end
    WaitForStartingServerWorker.perform_in(32.seconds, minecraft.user_id, id)
    self.update_columns(pending_operation: 'starting')
    return nil
  end

  def stop
    error = remote.shutdown
    if error
      return error
    end
    self.update_columns(pending_operation: 'stopping')
    WaitForStoppingServerWorker.perform_in(16.seconds, id)
    return nil
  end

  def reboot
    error = remote.reboot
    if error
      return error
    end
    self.update_columns(pending_operation: 'rebooting')
    WaitForStartingServerWorker.perform_in(4.seconds, minecraft.user_id, id)
    return nil
  end

  def busy?
    if !pending_operation.blank?
      return true
    end
    return false
  end

  def running?
    return remote.exists? && !remote.error? && remote.status == 'active'
  end

  def done_setup?
    return remote_setup_stage >= setup_stages
  end

  def setup_stages
    return 5
  end

  def reset
    update_columns(pending_operation: nil, remote_setup_stage: 0)
  end

  def reset_partial
    update_columns(pending_operation: nil)
  end

end
