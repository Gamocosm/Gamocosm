# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  remote_id           :integer
#  created_at          :datetime
#  updated_at          :datetime
#  minecraft_server_id :uuid
#

class Droplet < ActiveRecord::Base
  belongs_to :minecraft_server

  validates :remote_id, numericality: { only_integer: true }, allow_nil: true

  before_validation :before_validate_callback

  def before_validate_callback
    self.remote_id = self.remote_id.blank? ? nil : self.remote_id
  end

  def remote
    if @remote.nil?
      @remote = DigitalOcean::Droplet.new(self)
    end
    return @remote
  end

  def host_name
    return "gamocosm-minecraft-#{minecraft_server.name}"
  end

  def ip_address
    return remote.ip_address
  end

  def remote_status
    return remote.status
  end

  def remote_busy?
    return remote.busy?
  end
end
