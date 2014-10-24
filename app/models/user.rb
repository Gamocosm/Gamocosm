# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  created_at             :datetime
#  updated_at             :datetime
#  digital_ocean_api_key  :string(255)
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :minecrafts, dependent: :destroy
  has_and_belongs_to_many :friend_minecrafts, foreign_key: 'user_id', class_name: 'Minecraft'

  before_validation :before_validate_callback

  def before_validate_callback
    self.digital_ocean_api_key = self.digital_ocean_api_key.blank? ? nil : self.digital_ocean_api_key.strip.downcase
  end

  def digital_ocean_missing?
    return digital_ocean_api_key.blank?
  end

  def digital_ocean_invalid?
    if @digital_ocean_invalid.nil?
      if digital_ocean_missing?
        @digital_ocean_invalid = true
      else
        @digital_ocean_droplets = digital_ocean.droplet.all
        @digital_ocean_invalid = !@digital_ocean_droplets.success?
      end
    end
    return @digital_ocean_invalid
  end

  def digital_ocean
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_connection.nil?
      @digital_ocean_connection = DigitalOcean::Connection.new(digital_ocean_api_key).request
    end
    return @digital_ocean_connection
  end

  def digital_ocean_add_ssh_key(name, public_key)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    response = digital_ocean.key.create(name: name, public_key: public_key)
    if !response.success?
      return "Error adding Digital Ocean SSH key; they responded with #{response}"
    end
    return nil
  end

  def digital_ocean_ssh_public_key(id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    response = digital_ocean.key.show(id)
    if !response.success?
      return "Error getting Digital Ocean SSH key #{id}; they responded with #{response}".error!
    end
    return response.ssh_key.public_key
  end

  def digital_ocean_ssh_keys
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_ssh_keys.nil?
      response = digital_ocean.key.all
      if !response.success?
        @digital_ocean_ssh_keys = false
      else
        @digital_ocean_ssh_keys = response.ssh_keys
      end
    end
    return @digital_ocean_ssh_keys == false ? nil : @digital_ocean_ssh_keys
  end

  def digital_ocean_snapshots
    if digital_ocean_invalid?
      return nil
    end
    if @digital_ocean_snapshots.nil?
      response = digital_ocean.image.all
      if !response.success?
        @digital_ocean_snapshots = false
      else
        @digital_ocean_snapshots = response.images.select { |x| !x.public }
      end
    end
    return @digital_ocean_snapshots == false ? nil : @digital_ocean_snapshots
  end

  def digital_ocean_droplets
    if digital_ocean_invalid?
      return nil
    end
    return @digital_ocean_droplets.droplets
  end

  def digital_ocean_gamocosm_ssh_key_id
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    public_key = File.read(Gamocosm.digital_ocean_ssh_public_key_path)
    fingerprint = Digest::MD5.hexdigest(Base64.decode64(public_key.split(/\s+/m)[1])).scan(/../).join(':')
    keys = digital_ocean.key.all
    if !keys.success?
      return "Unable to get keys; Digital Ocean responded with #{keys}".error!
    end
    for x in keys.ssh_keys
      if x.fingerprint == fingerprint
        return x.id
      end
    end
    response = digital_ocean.key.create(name: 'gamocosm', public_key: public_key)
    if response.success?
      return response.ssh_key.id
    end
    return "Unable to add key; Digital Ocean responded with #{response}".error!
  end

  def invalidate
    @digital_ocean_invalid = nil
    @digital_ocean_snapshots = nil
  end
end
