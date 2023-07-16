# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
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

  has_many :servers, dependent: :destroy
  has_many :volumes, dependent: :destroy
  has_and_belongs_to_many :friend_servers, foreign_key: 'user_id', class_name: 'Server', dependent: :destroy

  before_validation :before_validate_callback

  def before_validate_callback
    self.digital_ocean_api_key = self.digital_ocean_api_key.clean
  end

  def digital_ocean_servers_cache
    return "user-#{self.id}-servers"
  end

  def digital_ocean_images_cache
    return "user-#{self.id}-images"
  end

  def digital_ocean_volumes_cache
    return "user-#{self.id}-volumes"
  end

  def digital_ocean_snapshots_cache
    return "user-#{self.id}-snapshots"
  end

  def digital_ocean_ssh_keys_cache
    return "user-#{self.id}-ssh_keys"
  end

  def digital_ocean_missing?
    return digital_ocean_api_key.blank?
  end

  def digital_ocean
    if @digital_ocean_connection.nil?
      @digital_ocean_connection = DigitalOcean::Connection.new(digital_ocean_api_key)
    end
    return @digital_ocean_connection
  end

  def invalidate
    self.invalidate_digital_ocean_cache_droplets
    self.invalidate_digital_ocean_cache_images
    self.invalidate_digital_ocean_cache_volumes
    self.invalidate_digital_ocean_cache_snapshots
    self.invalidate_digital_ocean_cache_ssh_keys
  end

  def invalidate_digital_ocean_cache_ssh_keys
    @digital_ocean_ssh_keys = nil
    Rails.cache.delete(self.digital_ocean_ssh_keys_cache)
  end

  def invalidate_digital_ocean_cache_droplets
    @digital_ocean_droplets = nil
    Rails.cache.delete(self.digital_ocean_servers_cache)
  end

  def invalidate_digital_ocean_cache_images
    @digital_ocean_images = nil
    Rails.cache.delete(self.digital_ocean_images_cache)
  end

  def invalidate_digital_ocean_cache_volumes
    @digital_ocean_volumes = nil
    Rails.cache.delete(self.digital_ocean_volumes_cache)
  end

  def invalidate_digital_ocean_cache_snapshots
    @digital_ocean_snapshots = nil
    Rails.cache.delete(self.digital_ocean_snapshots_cache)
  end

  def digital_ocean_droplets
    if digital_ocean_missing?
      return nil
    end
    # if we haven't cached it this request
    if @digital_ocean_droplets.nil?
      droplets = Rails.cache.read(self.digital_ocean_servers_cache)
      # if we haven't cached it recently
      if droplets.nil?
        droplets = self.digital_ocean.droplet_list
        if !droplets.error?
          Rails.cache.write(self.digital_ocean_servers_cache, droplets, expires_in: 24.hours)
        end
      end
      # cache the result for this request (if there was an error, don't keep trying)
      @digital_ocean_droplets = droplets
    end
    return @digital_ocean_droplets
  end

  def digital_ocean_images
    # parallel to User#digital_ocean_droplets
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_images.nil?
      images = Rails.cache.read(self.digital_ocean_images_cache)
      if images.nil?
        images = self.digital_ocean.image_list(true)
        if !images.error?
          Rails.cache.write(self.digital_ocean_images_cache, images, expires_in: 24.hours)
        end
      end
      @digital_ocean_images = images
    end
    return @digital_ocean_images
  end

  def digital_ocean_volumes
    # parallel to User#digital_ocean_droplets
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_volumes.nil?
      volumes = Rails.cache.read(self.digital_ocean_volumes_cache)
      if volumes.nil?
        volumes = self.digital_ocean.volume_list
        if !volumes.error?
          Rails.cache.write(self.digital_ocean_volumes_cache, volumes, expires_in: 24.hours)
        end
      end
      @digital_ocean_volumes = volumes
    end
    return @digital_ocean_volumes
  end

  def digital_ocean_snapshots
    # parallel to User#digital_ocean_droplets
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_snapshots.nil?
      snapshots = Rails.cache.read(self.digital_ocean_snapshots_cache)
      if snapshots.nil?
        snapshots = self.digital_ocean.snapshot_list
        if !snapshots.error?
          Rails.cache.write(self.digital_ocean_snapshots_cache, snapshots, expires_in: 24.hours)
        end
      end
      @digital_ocean_snapshots = snapshots
    end
    return @digital_ocean_snapshots
  end

  def digital_ocean_ssh_keys
    # parallel to User#digital_ocean_droplets
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_ssh_keys.nil?
      keys = Rails.cache.read(self.digital_ocean_ssh_keys_cache)
      if keys.nil?
        keys = self.digital_ocean.ssh_key_list
        if !keys.error?
          Rails.cache.write(self.digital_ocean_ssh_keys_cache, keys, expires_in: 24.hours)
        end
      end
      @digital_ocean_ssh_keys = keys
    end
    return @digital_ocean_ssh_keys
  end

  def digital_ocean_gamocosm_ssh_key_id
    gamocosm_key = Gamocosm.ssh_public_key
    self.invalidate_digital_ocean_cache_ssh_keys
    keys = self.digital_ocean_ssh_keys
    if keys.error?
      return keys
    end
    if keys.nil?
      return 'You do not have a Digital Ocean API key'.error!(nil)
    end
    for x in keys
      if x.fingerprint == gamocosm_key.fingerprint
        return x.id
      end
    end
    res = self.digital_ocean.ssh_key_create('gamocosm', gamocosm_key.contents)
    if res.error?
      return res
    end
    return res.id
  end
end
