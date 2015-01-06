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
    self.pending_operation = self.pending_operation.blank? ? nil : self.pending_operation.strip.downcase
    self.do_saved_snapshot_id = self.do_saved_snapshot_id.blank? ? nil : self.do_saved_snapshot_id
    self.do_region_slug = self.do_region_slug.strip.downcase
    self.do_size_slug = self.do_size_slug.strip.downcase
    self.ssh_keys = self.ssh_keys.try(:gsub, ' ', '')
    self.ssh_keys = self.ssh_keys.blank? ? nil : self.ssh_keys
  end

  def remote
    if @remote.nil?
      @remote = DigitalOcean::Droplet.new(self)
    end
    return @remote
  end

  def host_name
    return "#{minecraft.name}.minecraft.gamocosm"
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
    WaitForStartingServerWorker.perform_in(32.seconds, minecraft.user_id, id, remote.action_id)
    self.update_columns(pending_operation: 'starting')
    return nil
  end

  def stop
    error = remote.shutdown
    if error
      return error
    end
    self.update_columns(pending_operation: 'stopping')
    WaitForStoppingServerWorker.perform_in(16.seconds, id, remote.action_id)
    return nil
  end

  def reboot
    error = remote.reboot
    if error
      return error
    end
    self.update_columns(pending_operation: 'rebooting')
    WaitForStartingServerWorker.perform_in(4.seconds, minecraft.user_id, id, remote.action_id)
    return nil
  end

  def busy?
    if !pending_operation.blank?
      if remote_id.nil? && do_saved_snapshot_id.nil?
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

  # Should be unused
  def reset
    update_columns(pending_operation: nil, remote_setup_stage: 0)
  end

  def reset_partial
    update_columns(pending_operation: nil)
  end

  def refresh_domain
    connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_api_key).request
    if self.server_domain.nil?
      while true do
        begin
          self.create_server_domain
          break
        rescue ActiveRecord::RecordNotUnique
        end
      end
      begin
        response = connection.domain.create_record(Gamocosm.domain, { type: 'A', name: self.server_domain.name, data: self.remote.ip_address || '127.0.0.1' })
        if !response.success?
          return "Error creating domain on Digital Ocean; they responded with #{response}"
        end
      rescue
        self.server_domain.delete
        return "Exception creating domain on Digital Ocean: #{e}"
      end
    else
      response = connection.domain.records(Gamocosm.domain)
      if !response.success?
        return "Error fetching domains from Digital Ocean; they responded with #{response}"
      end
      found = false
      response.domain_records.each do |x|
        if x.type == 'A' && x.name == self.server_domain.name
          found = true
          connection.domain.update_record(Gamocosm.domain, x.id, { data: self.remote.ip_address })
          break
        end
      end
      if !found
        raise 'Badness! Server domain exists in database, but not on Digital Ocean'
      end
    end
    return nil
  end

  def remove_domain
    if self.server_domain.nil?
      return nil
    end
    connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_api_key).request
    response = connection.domain.records(Gamocosm.domain)
    if !response.success?
      return "Error fetching domains from Digital Ocean; they responded with #{response}"
    end
    response.domain_records.each do |x|
      if x.type == 'A' && x.name == self.server_domain.name
        response2 = connection.domain.destroy_record(Gamocosm.domain, x.id)
        if !response2.success?
          return "Error deleting domain from Digital Ocean; they responded with #{response}"
        end
        break
      end
    end
    self.server_domain.delete
    return nil
  end

end
