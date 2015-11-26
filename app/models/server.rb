# == Schema Information
#
# Table name: servers
#
#  id                 :uuid             not null, primary key
#  user_id            :integer          not null
#  name               :string(255)      not null
#  created_at         :datetime
#  updated_at         :datetime
#  domain             :string           not null
#  pending_operation  :string
#  ssh_port           :integer          default(4022), not null
#  ssh_keys           :string
#  setup_stage        :integer          default(0), not null
#  remote_id          :integer
#  remote_region_slug :string           not null
#  remote_size_slug   :string           not null
#  remote_snapshot_id :integer
#  timezone_delta     :integer          default(0), not null
#

class Server < ActiveRecord::Base
  belongs_to :user
  has_one :minecraft, dependent: :destroy
  has_and_belongs_to_many :friends, foreign_key: 'server_id', class_name: 'User', dependent: :destroy
  has_many :logs, foreign_key: 'server_id', class_name: 'ServerLog', dependent: :destroy
  has_many :scheduled_tasks, dependent: :destroy

  validates :name, length: { in: 3...64 }
  validates :name, format: { with: /\A[a-z][a-z0-9-]*[a-z0-9]\z/, message: 'Name must start with a letter, and end with a letter or number. May include letters, numbers, and dashes in between' }
  validates :setup_stage, numericality: { only_integer: true }
  validates :ssh_keys, format: { with: /\A\d+(,\d+)*\z/, message: 'Invalid list of comma separated IDs' }, allow_nil: true
  validates :remote_id, numericality: { only_integer: true }, allow_nil: true
  validates :remote_snapshot_id, numericality: { only_integer: true }, allow_nil: true
  validates :remote_region_slug, presence: true
  validates :remote_size_slug, presence: true
  validates :ssh_port, numericality: { only_integer: true }
  validates :timezone_delta, numericality: { only_integer: true, greater_than: -24, less_than: 24 }

  after_initialize :after_initialize_callback
  before_validation :before_validate_callback

  accepts_nested_attributes_for :minecraft

  def after_initialize_callback
    chars = ('a'..'z').to_a
    self.domain ||= (0...8).map { chars[rand(chars.length)] }.join
  end

  def before_validate_callback
    self.name = self.name.strip.downcase.gsub(' ', '-')
    self.remote_id = self.remote_id.blank? ? nil : self.remote_id
    self.pending_operation = self.pending_operation.clean
    self.remote_snapshot_id = self.remote_snapshot_id.blank? ? nil : self.remote_snapshot_id
    self.remote_region_slug = self.remote_region_slug.clean
    self.remote_size_slug = self.remote_size_slug.clean
    self.ssh_keys = self.ssh_keys.try(:gsub, /\s/, '').clean
  end

  def schedule_text
    return self.scheduled_tasks.map { |x| x.to_user_string }.join("\n")
  end

  def parse_and_save_schedule(text)
    tasks = ScheduledTask.parse(text, self)
    if tasks.error?
      self.errors.add(:schedule_text, tasks.msg)
      return false
    end
    self.scheduled_tasks.delete_all
    tasks.each do |t|
      if !t.save
        self.errors.add(:schedule_text, 'Unknown error saving schedule item')
        return false
      end
    end
    return true
  end

  def host_name
    return "#{name}.minecraft.gamocosm"
  end

  def ram
    size = Gamocosm.digital_ocean.size_find(remote_size_slug)
    if size.nil?
      log("Unknown Digital Ocean size slug #{remote_size_slug}; only starting server with 512MB of RAM")
      return 512
    end
    return size.memory
  end

  def remote
    if @remote.nil?
      @remote = ServerRemote.new(self)
    end
    return @remote
  end

  def done_setup?
    return setup_stage >= num_setup_stages
  end

  def num_setup_stages
    return 5
  end

  def reset_state
    update_columns(pending_operation: nil)
  end

  def running?
    return remote.exists? && !remote.error? && remote.status == 'active'
  end

  def owner?(someone)
    if new_record?
      return true
    end
    return someone.id == user_id
  end

  def friend?(someone)
    return friends.exists?(someone.id)
  end

  def log(message)
    where = caller[0].split(':')
    logs.create(message: message, debuginfo: Pathname.new(where[0]).relative_path_from(Rails.root).to_s + ':' + where.drop(1).join(':'))
  end

  def log_test(message)
    log(message)
  end

  def refresh_domain
    ip_address = remote.ip_address
    if ip_address.error?
      return ip_address
    end
    return Gamocosm.cloudflare.dns_update(domain, ip_address)
  end

  def remove_domain
    return Gamocosm.cloudflare.dns_delete(domain)
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
    error = start?
    if error
      return error
    end
    action = remote.create
    if action.error?
      return action
    end
    WaitForStartingServerWorker.perform_in(32.seconds, id, action.id)
    self.update_columns(pending_operation: 'starting')
    return nil
  end

  def stop
    error = stop?
    if error
      return error
    end
    action = remote.shutdown
    if action.error?
      # action `unprocesable_entity`, already off
      if action.data.status == 422 && remote.status == 'off'
        action = remote.snapshot
        if action.error?
          return action
        end
        self.update_columns(pending_operation: 'saving')
        WaitForSnapshottingServerWorker.perform_in(16.seconds, id, action.id)
        return nil
      else
        return action
      end
    end
    self.update_columns(pending_operation: 'stopping')
    WaitForStoppingServerWorker.perform_in(16.seconds, id, action.id)
    return nil
  end

  def reboot
    error = reboot?
    if error
      return error
    end
    action = remote.reboot
    if action.error?
      return action
    end
    self.update_columns(pending_operation: 'rebooting')
    WaitForStartingServerWorker.perform_in(4.seconds, id, action.id)
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
end
