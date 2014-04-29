# == Schema Information
#
# Table name: droplets
#
#  id                  :integer          not null, primary key
#  minecraft_server_id :integer
#  remote_id           :integer
#  remote_size_id      :integer
#  remote_region_id    :integer
#  ip_address          :inet
#  remote_status       :string(255)
#  last_synced         :datetime
#  created_at          :datetime
#  updated_at          :datetime
#

class Droplet < ActiveRecord::Base
  belongs_to :minecraft_server
end
