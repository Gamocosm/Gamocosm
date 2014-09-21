# == Schema Information
#
# Table name: minecrafts
#
#  id                         :uuid             not null, primary key
#  user_id                    :integer
#  name                       :string(255)      not null
#  created_at                 :datetime
#  updated_at                 :datetime
#  minecraft_wrapper_password :string(255)      not null
#

class Minecraft < ActiveRecord::Base
  belongs_to :user
  has_one :server, dependent: :destroy
  has_and_belongs_to_many :friends, foreign_key: 'minecraft_id', class_name: 'User', dependent: :destroy

  validates :name, format: { with: /\A[a-zA-Z0-9-]{1,63}(\.[a-zA-Z0-9-]{1,63})*\z/ }
  validates :name, length: { in: 3..128 }

  after_initialize :after_initialize_callback
  before_validation :before_validate_callback

  accepts_nested_attributes_for :server

  def after_initialize_callback
    self.minecraft_wrapper_password ||= SecureRandom.hex
  end

  def before_validate_callback
    self.name = self.name.strip.downcase
  end

  def running?
    return server.running? && !node.pid.error? && node.pid > 0
  end

  def start
    if server.remote.exists?
      return nil
    end
    if server.busy?
      return 'Server is busy'
    end
    return server.start
  end

  def stop
    if !server.remote.exists?
      return nil
    end
    if server.busy?
      return 'Server is busy'
    end
    if !node.pause
      Rails.logger.warn "MC#stop: node.pause return false, MC #{id}"
    end
    return server.stop
  end

  def reboot
    if !server.remote.exists?
      return nil
    end
    if server.busy?
      return 'Server is busy'
    end
    return server.reboot
  end

  def world_download_url
    if server.running?
      return "http://#{Gamocosm.minecraft_wrapper_username}:#{minecraft_wrapper_password}@#{server.ip_address}:5000/download_world"
    end
    return nil
  end

  def node
    if @node.nil?
      if !server.remote.error? && server.running?
        @node = Minecraft::Node.new(self, server.remote.ip_address, 5000)
      end
    end
    return @node
  end

  def properties
    if @properties.nil?
      if !server.remote.error? && server.running?
        @properties = Minecraft::Properties.new(self)
      end
    end
    return @properties
  end

  def is_owner?(someone)
    if new_record?
      return true
    end
    return someone.id == user.id
  end

  def is_friend?(someone)
    return friends.exists?(someone.id)
  end

end
