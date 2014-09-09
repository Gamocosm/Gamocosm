# == Schema Information
#
# Table name: minecraft_servers
#
#  id                         :uuid             not null, primary key
#  user_id                    :integer
#  name                       :string(255)
#  saved_snapshot_id          :integer
#  pending_operation          :string(255)
#  created_at                 :datetime
#  updated_at                 :datetime
#  remote_setup_stage         :integer          default(0)
#  minecraft_wrapper_password :string(255)
#  remote_ssh_setup_stage     :integer          default(0), not null
#  digital_ocean_region_slug  :string(255)
#  digital_ocean_size_slug    :string(255)
#

class MinecraftServer < ActiveRecord::Base
  belongs_to :user
  has_one :droplet, dependent: :destroy
  has_and_belongs_to_many :friends, foreign_key: 'minecraft_server_id', class_name: 'User', dependent: :destroy

  validates :name, format: { with: /\A[a-zA-Z0-9-]{1,63}(\.[a-zA-Z0-9-]{1,63})*\z/ }
  validates :name, length: { in: 3..128 }

  after_initialize :after_initialize_callback
  before_validation :before_validate_callback

  def after_initialize_callback
    self.minecraft_wrapper_password ||= SecureRandom.hex
  end

  def before_validate_callback
    self.name = self.name.downcase
    self.pending_operation = self.pending_operation.blank? ? nil : self.pending_operation
    self.saved_snapshot_id = self.saved_snapshot_id.nil? ? nil : self.saved_snapshot_id
    self.digital_ocean_region_slug = self.digital_ocean_region_slug.blank? ? nil: self.digital_ocean_region_slug
    self.digital_ocean_size_slug = self.digital_ocean_size_slug.blank? ? nil : self.digital_ocean_size_slug
  end

  def droplet_running?
    return droplet && droplet.remote_status == 'active'
  end

  def game_running?
    return droplet_running? && !node.pid.nil? && node.pid > 0
  end

  def busy?
    if pending_operation
      return true
    end
    if droplet && droplet.remote_busy?
      return true
    end
    return false
  end

  def start
    if droplet_running?
      return nil
    end
    if busy?
      return 'Server is busy' # TODO
    end
    self.create_droplet
    error = droplet.remote.create
    if error
      return error
    end
    self.update_columns(pending_operation: 'starting')
    WaitForStartingServerWorker.perform_in(32.seconds, user_id, droplet.id)
    return nil
  end

  def stop
    if !droplet_running?
      return nil
    end
    if busy?
      return 'Server is busy' # TODO
    end
    if !node.pause
      Rails.logger.warn "MC#stop: node.pause return false, MC #{id}"
    end
    error = droplet.remote.shutdown
    if error
      return error
    end
    self.update_columns(pending_operation: 'stopping')
    WaitForStoppingServerWorker.perform_in(16.seconds, droplet.id)
    return nil
  end

  def reboot
    error = droplet.remote.reboot
    if error
      return error
    end
    self.update_columns(pending_operation: 'rebooting')
    WaitForStartingServerWorker.perform_in(4.seconds, user_id, droplet.id)
    return nil
  end

  def destroy_remote
    if droplet.nil?
      return nil
    end
    return droplet.remote.destroy
  end

  def resume
    if node.nil?
      return false
    end
    return node.resume
  end

  def pause
    if node.nil?
      return false
    end
    return node.pause
  end

  def backup
    if node.nil?
      return false
    end
    return node.backup
  end

  def ram
    droplet_size = DigitalOcean::DropletSize.new.find(digital_ocean_size_slug)
    if droplet_size.nil?
      Rails.logger.warn "MC#ram: droplet size was nil, MC #{id}"
      return 512
    end
    return droplet_size[:memory]
  end

  def world_download_url
    if droplet_running?
      return "http://#{Gamocosm.minecraft_wrapper_username}:#{minecraft_wrapper_password}@#{droplet.ip_address}:5000/download_world"
    end
    return minecraft_server_path(self)
  end

  def node
    if @node.nil?
      if droplet_running?
        @node = MinecraftServer::Node.new(self, droplet.ip_address, 5000)
      end
    end
    return @node
  end

  def properties
    if @properties.nil?
      if droplet_running?
        @properties = MinecraftServer::Properties.new(self)
      end
    end
    return @properties
  end

  def is_owner?(someone)
    if user.nil?
      return true
    end
    return someone.id == user.id
  end

  def is_friend?(someone)
    return friends.exists?(someone.id)
  end

  def is_new?
    return digital_ocean_region_slug.nil?
  end

end
