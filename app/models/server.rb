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
#  ssh_keys             :string(255)
#  ssh_port             :integer          default(4022), not null
#

class Server < ActiveRecord::Base
  belongs_to :minecraft
  has_one :server_domain, dependent: :destroy

  validates :remote_id, numericality: { only_integer: true }, allow_nil: true
  validates :remote_setup_stage, numericality: { only_integer: true }
  validates :do_saved_snapshot_id, numericality: { only_integer: true }, allow_nil: true
  validates :do_region_slug, presence: true
  validates :do_size_slug, presence: true
  validates :ssh_keys, format: { with: /\A\d+(,\d+)*\z/, message: 'Invalid list of comma separated IDs' }, allow_nil: true

  before_validation :before_validate_callback

  def before_validate_callback
    self.remote_id = self.remote_id.blank? ? nil : self.remote_id
    self.pending_operation = self.pending_operation.clean
    self.do_saved_snapshot_id = self.do_saved_snapshot_id.blank? ? nil : self.do_saved_snapshot_id
    self.do_region_slug = self.do_region_slug.clean
    self.do_size_slug = self.do_size_slug.clean
    self.ssh_keys = self.ssh_keys.try(:gsub, /\s/, '').clean
  end

  def remote
    if @remote.nil?
      @remote = ServerRemote.new(self)
    end
    return @remote
  end

  def host_name
    return "#{minecraft.name}.minecraft.gamocosm"
  end

  def ram
    droplet_size = Gamocosm.digital_ocean.size_find(do_size_slug)
    if droplet_size.nil?
      minecraft.log("Unknown Digital Ocean size slug #{do_size_slug}; only starting server with 512MB of RAM")
      return 512
    end
    return droplet_size.memory
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
    action = remote.create
    if action.error?
      return action
    end
    WaitForStartingServerWorker.perform_in(32.seconds, minecraft.user_id, id, action.id)
    self.update_columns(pending_operation: 'starting')
    return nil
  end

  def stop
    action = remote.shutdown
    if action.error?
      return action
    end
    self.update_columns(pending_operation: 'stopping')
    WaitForStoppingServerWorker.perform_in(16.seconds, minecraft.user_id, id, action.id)
    return nil
  end

  def reboot
    action = remote.reboot
    if action.error?
      return action
    end
    self.update_columns(pending_operation: 'rebooting')
    WaitForStartingServerWorker.perform_in(4.seconds, minecraft.user_id, id, action.id)
    return nil
  end

  def busy?
    if !pending_operation.blank?
      if remote_id.nil?
        self.update_columns(pending_operation: nil)
        return false
      end
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

  def reset_partial
    update_columns(pending_operation: nil)
  end

  def refresh_domain
    ip_address = remote.ip_address
    if ip_address.error?
      return ip_address
    end
    if self.server_domain.nil?
      while true do
        begin
          self.create_server_domain
          break
        rescue ActiveRecord::RecordNotUnique
        end
      end
      return Gamocosm.cloudflare.dns_add(self.server_domain.name, ip_address)
    end
    return Gamocosm.cloudflare.dns_update(self.server_domain.name, ip_address)
  end

  def remove_domain
    if self.server_domain.nil?
      return nil
    end
    return Gamocosm.cloudflare.dns_delete(self.server_domain.name)
  end

end
