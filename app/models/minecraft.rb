# == Schema Information
#
# Table name: minecrafts
#
#  id                           :bigint           not null, primary key
#  created_at                   :datetime
#  updated_at                   :datetime
#  server_id                    :uuid             not null
#  flavour                      :string           not null
#  mcsw_password                :string           not null
#  autoshutdown_enabled         :boolean          default(FALSE), not null
#  autoshutdown_last_check      :datetime         not null
#  autoshutdown_last_successful :datetime         not null
#  autoshutdown_minutes         :integer          default(8), not null
#

class Minecraft < ActiveRecord::Base
  belongs_to :server

  validates :autoshutdown_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 5, less_than: 24 * 60 }

  after_initialize :after_initialize_callback
  before_validation :before_validate_callback

  def after_initialize_callback
    self.autoshutdown_last_check ||= Time.now
    self.autoshutdown_last_successful ||= Time.now
    self.mcsw_password ||= SecureRandom.hex(16)
  end

  def before_validate_callback
    if self.new_record?
      if !Gamocosm::MINECRAFT_FLAVOURS.has_key?(self.flavour)
        self.errors.add(:flavour, 'Invalid flavour')
      end
    end
  end

  def flavour_info
    Gamocosm::MINECRAFT_FLAVOURS[self.flavour]
  end

  def node
    if @node.nil?
      if server.running?
        @node = Minecraft::Node.new(self, server.remote.ip_address)
      end
    end
    @node
  end

  def properties
    if @properties.nil?
      if server.running?
        response = node.properties
        if response.error?
          server.log("Error getting Minecraft properties: #{response}")
          @properties = response
        else
          @properties = Minecraft::Properties.new(response)
        end
      end
    end
    @properties
  end

  def world_download_url
    if server.running?
      return "http://#{Gamocosm::MCSW_USERNAME}:#{mcsw_password}@#{server.remote.ip_address}:#{Minecraft::Node::MCSW_PORT}/download_world"
    end
    nil
  end

  def running?
    server.running? && !node.error? && node.pid > 0
  end

  def resume
    error = resume?
    if error
      return error
    end
    node.resume
  end

  def pause
    error = pause?
    if error
      if server.running? && !node.error? && !(node.pid > 0)
        return nil
      end
      return error
    end
    node.pause
  end

  def exec(current_user, command)
    error = exec?(current_user)
    if error
      return error
    end
    node.exec(command)
  end

  def backup
    error = backup?
    if error
      return error
    end
    node.backup
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
    nil
  end

  def pause?
    if !server.running?
      return 'Server not running'
    end
    if node.error?
      return node.pid
    end
    if !(node.pid > 0)
      return 'Minecraft not running'
    end
    nil
  end

  def exec?(current_user)
    if !server.owner?(current_user)
      return 'Only the server owner can execute commands'
    end
    # the next three are the same as !running?
    if !server.running?
      return 'Server not running'
    end
    if node.error?
      return node.pid
    end
    if !(node.pid > 0)
      return 'Minecraft not running'
    end
    nil
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
    nil
  end

  def download?
    backup?
  end
end
