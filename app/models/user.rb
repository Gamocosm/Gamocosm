# == Schema Information
#
# Table name: users
#
#  id                                  :integer          not null, primary key
#  email                               :string(255)      default(""), not null
#  encrypted_password                  :string(255)      default(""), not null
#  reset_password_token                :string(255)
#  reset_password_sent_at              :datetime
#  remember_created_at                 :datetime
#  sign_in_count                       :integer          default(0), not null
#  current_sign_in_at                  :datetime
#  last_sign_in_at                     :datetime
#  current_sign_in_ip                  :string(255)
#  last_sign_in_ip                     :string(255)
#  created_at                          :datetime
#  updated_at                          :datetime
#  digital_ocean_client_id             :string(255)
#  digital_ocean_api_key               :string(255)
#  digital_ocean_minecraft_snapshot_id :integer
#  digital_ocean_event_id              :integer
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :minecraft_servers, dependent: :destroy
  has_and_belongs_to_many :friend_minecraft_servers, foreign_key: 'user_id', class_name: 'MinecraftServer'

  def minecraft_snapshot_id
    if digital_ocean_minecraft_snapshot_id.nil?
      return nil
    end
    if digital_ocean.nil?
      return nil
    end
    if digital_ocean.images.list.index { |x| x.image_id == digital_ocean_minecraft_snapshot_id }.nil?
      return nil
    end
    return digital_ocean_minecraft_snapshot_id
  end

  def digital_ocean
    if digital_ocean_client_id.nil? || digital_ocean_api_key.nil?
      return nil
    end
    if @digital_ocean_connection.nil?
      @digital_ocean_connection = DigitalOcean::Connection.new(digital_ocean_client_id, digital_ocean_api_key).request
    end
    return @digital_ocean_connection
  end

  def digital_ocean_droplets
    if digital_ocean.nil?
      return nil
    end
    return [] # TODO
  end
end
