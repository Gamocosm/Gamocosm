# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  remote_id           :integer
#  ip_address          :inet
#  remote_status       :string(255)
#  last_synced         :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  minecraft_server_id :uuid
#  remote_region_slug  :string(255)
#  remote_size_slug    :string(255)
#

class Droplet < ActiveRecord::Base
  belongs_to :minecraft_server

  def remote
    return DigitalOcean::Droplet.new(self)
  end

  def host_name
    return "gamocosm-minecraft-#{minecraft_server.name}"
  end
end
