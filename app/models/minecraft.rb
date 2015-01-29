# == Schema Information
#
# Table name: minecrafts
#
#  id                           :uuid             not null, primary key
#  user_id                      :integer          not null
#  name                         :string(255)      not null
#  created_at                   :datetime
#  updated_at                   :datetime
#  minecraft_wrapper_password   :string(255)      not null
#  autoshutdown_enabled         :boolean          default(FALSE), not null
#  autoshutdown_last_check      :datetime
#  autoshutdown_last_successful :datetime
#  flavour                      :string(255)      default("vanilla/null"), not null
#

class Minecraft < ActiveRecord::Base
  belongs_to :user
  has_one :server, dependent: :destroy
  has_and_belongs_to_many :friends, foreign_key: 'minecraft_id', class_name: 'User', dependent: :destroy
  has_many :logs, foreign_key: 'minecraft_id', class_name: 'ServerLog', dependent: :destroy

  validates :name, length: { in: 3...64 }
  validates :name, format: { with: /\A[a-z][a-z0-9-]*[a-z0-9]\z/, message: 'Name must start with a letter, and end with a letter or number. May include letters, numbers, and dashes in between' }

  after_initialize :after_initialize_callback
  before_validation :before_validate_callback

  accepts_nested_attributes_for :server

  def after_initialize_callback
    self.minecraft_wrapper_password ||= SecureRandom.hex
  end

  def before_validate_callback
    self.name = self.name.strip.downcase.gsub(' ', '-')
    if self.new_record?
      if !Gamocosm.minecraft_flavours.has_key?(self.flavour)
        self.errors.add(:flavour, 'Invalid flavour')
      end
    end
  end

  def running?
    return server.running? && !node.error? && node.pid > 0
  end

  def resume?
    if !server.running?
      return 'Server not running'
    end
    if node.error?
      return node.pid
    end
    if node.pid > 0
      return 'Minecraft already running'
    end
    return nil
  end

  def pause?
    if !server.running?
      return 'Server not running'
    end
    if node.error?
      return node.pid
    end
    if !(node.pid > 0)
      return 'Minecraft already stopped'
    end
    return nil
  end

  def backup?
    if !server.running?
      return 'Server not running'
    end
    if node.error?
      return node.pid
    end
    if node.pid > 0
      return 'Minecraft is running'
    end
    return nil
  end

  def download?
    return backup?
  end

  def start
    error = server.start?
    if error
      return error
    end
    return server.start
  end

  def stop
    error = server.stop?
    if error
      return error
    end
    return server.stop
  end

  def reboot
    error = server.reboot?
    if error
      return error
    end
    return server.reboot
  end

  def world_download_url
    if server.running?
      return "http://#{Gamocosm.minecraft_wrapper_username}:#{minecraft_wrapper_password}@#{server.remote.ip_address}:5000/download_world"
    end
    return nil
  end

  def node
    if @node.nil?
      if server.running?
        @node = Minecraft::Node.new(self, server.remote.ip_address, 5000)
      end
    end
    return @node
  end

  def properties
    if @properties.nil?
      if server.running?
        @properties = Minecraft::Properties.new(self)
      end
    end
    return @properties
  end

  def flavour_info
    return Gamocosm.minecraft_flavours[self.flavour]
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

end
