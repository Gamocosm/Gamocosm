# == Schema Information
#
# Table name: minecrafts
#
#  id                           :integer          not null, primary key
#  created_at                   :datetime
#  updated_at                   :datetime
#  server_id                    :uuid             not null
#  flavour                      :string           not null
#  mcsw_password                :string           not null
#  autoshutdown_enabled         :boolean          default("false"), not null
#  autoshutdown_last_check      :datetime         not null
#  autoshutdown_last_successful :datetime         not null
#

class Minecraft < ActiveRecord::Base
  belongs_to :server

  after_initialize :after_initialize_callback
  before_validation :before_validate_callback

  def after_initialize_callback
    self.autoshutdown_last_check ||= Time.now
    self.autoshutdown_last_successful ||= Time.now
    self.mcsw_password ||= SecureRandom.hex
  end

  def before_validate_callback
    if self.new_record?
      if !Gamocosm::MINECRAFT_FLAVOURS.has_key?(self.flavour)
        self.errors.add(:flavour, 'Invalid flavour')
      end
    end
  end

  def flavour_info
    return Gamocosm::MINECRAFT_FLAVOURS[self.flavour]
  end

  def node
    if @node.nil?
      if server.running?
        @node = Minecraft::Node.new(self, server.remote.ip_address)
      end
    end
    return @node
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
    return @properties
  end

  def world_download_url
    if server.running?
      return "http://#{Gamocosm::MCSW_USERNAME}:#{mcsw_password}@#{server.remote.ip_address}:#{Minecraft::Node::MCSW_PORT}/download_world"
    end
    return nil
  end

  def running?
    return server.running? && !node.error? && node.pid > 0
  end

  def resume
    error = resume?
    if error
      return error
    end
    return node.resume
  end

  def pause
    error = pause?
    if error
      return error
    end
    return node.pause
  end

  def exec(current_user, command)
    error = exec?(current_user)
    if error
      return error
    end
    return node.exec(command)
  end

  def backup
    error = backup?
    if error
      return error
    end
    return node.backup
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
      return 'Minecraft not running'
    end
    return nil
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
    backup?
  end
end
