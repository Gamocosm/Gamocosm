# == Schema Information
#
# Table name: minecraft_servers
#
#  id                :uuid             not null, primary key
#  user_id           :integer
#  name              :string(255)
#  saved_snapshot_id :integer
#  pending_operation :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#

class MinecraftServer < ActiveRecord::Base
  belongs_to :user
  has_one :droplet
end
