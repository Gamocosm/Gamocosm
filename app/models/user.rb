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
    self.digital_ocean_api_key = self.digital_ocean_api_key.clean
  end

  def digital_ocean_servers_cache
    return "user-#{self.id}-servers"
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
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_connection.nil?
      @digital_ocean_connection = DigitalOcean::Connection.new(digital_ocean_api_key).request
    end
    return @digital_ocean_connection
  end

  def invalidate
    @digital_ocean_droplets = nil
    @digital_ocean_snapshots = nil
    Rails.cache.delete(self.digital_ocean_servers_cache)
    Rails.cache.delete(self.digital_ocean_snapshots_cache)
    self.invalidate_digital_ocean_cache_ssh_keys
  end

  def invalidate_digital_ocean_cache_ssh_keys
    @digital_ocean_ssh_keys = nil
    Rails.cache.delete(self.digital_ocean_ssh_keys_cache)
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
        begin
          response = self.digital_ocean.droplet.all
          if response.success?
            droplets = response.droplets
            Rails.cache.write(self.digital_ocean_servers_cache, droplets.map { |x| x.to_hash }, expires_in: 24.hours)
          else
            droplets = "Error communicating with Digital Ocean: #{response}".error!
          end
        rescue Faraday::Error => e
          Rails.logger.error e.inspect
          Rails.logger.error e.backtrace.join("\n")
          droplets = "Exception communicating with Digital Ocean: #{e}".error!
        end
      else
        droplets = droplets.map { |x| Hashie::Mash.new(x) }
      end
      # cache the result for this request (if there was an error, don't keep trying)
      @digital_ocean_droplets = droplets
    end
    return @digital_ocean_droplets
  end

  def digital_ocean_snapshots
    # parallel to User#digital_ocean_droplets
    if digital_ocean_missing?
      return nil
    end
    if @digital_ocean_snapshots.nil?
      snapshots = Rails.cache.read(self.digital_ocean_snapshots_cache)
      if snapshots.nil?
        begin
          response = self.digital_ocean.image.all
          if response.success?
            snapshots = response.images.select { |x| !x.public }
            Rails.cache.write(self.digital_ocean_snapshots_cache, snapshots.map { |x| x.to_hash }, expires_in: 24.hours)
          else
            snapshots = "Error communicating with Digital Ocean: #{response}".error!
          end
        rescue Faraday::Error => e
          Rails.logger.error e.inspect
          Rails.logger.error e.backtrace.join("\n")
          snapshots = "Exception communicating with Digital Ocean: #{e}".error!
        end
      else
        snapshots = snapshots.map { |x| Hashie::Mash.new(x) }
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
        begin
          response = digital_ocean.key.all
          if response.success?
            keys = response.ssh_keys
            Rails.cache.write(self.digital_ocean_ssh_keys_cache, keys.map { |x| x.to_hash }, expires_in: 24.hours)
          else
            keys = "Error getting Digital Ocean SSH keys: #{response}".error!
          end
        rescue Faraday::Error => e
          Rails.logger.error e.inspect
          Rails.logger.error e.backtrace.join("\n")
          keys = "Exception communicating with Digital Ocean: #{e}".error!
        end
      else
        keys = keys.map { |x| Hashie::Mash.new(x) }
      end
      @digital_ocean_ssh_keys = keys
    end
    return @digital_ocean_ssh_keys
  end

  def digital_ocean_add_ssh_key(name, public_key)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'
    end
    self.invalidate_digital_ocean_cache_ssh_keys
    response = nil
    begin
      response = digital_ocean.key.create(name: name, public_key: public_key)
      if !response.success?
        return "Error adding Digital Ocean SSH key: #{response}".error!
      end
    rescue Faraday::Error => e
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n")
      return "Exception communicating with Digital Ocean: #{e}".error!
    end
    return response.ssh_key.id
  end

  def digital_ocean_delete_ssh_key(remote_id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'
    end
    self.invalidate_digital_ocean_cache_ssh_keys
    begin
      response = digital_ocean.key.destroy(remote_id)
      if !response.success?
        return "Error deleting Digital Ocean SSH key: #{response}"
      end
    rescue Faraday::Error => e
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n")
      return "Exception communicating with Digital Ocean: #{e}"
    end
    return nil
  end

  def digital_ocean_delete_droplet(remote_id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'
    end
    self.invalidate
    begin
      response = digital_ocean.droplet.destroy(remote_id)
      if !response.success?
        return "Error deleting Digital Ocean droplet: #{response}"
      end
    rescue Faraday::Error => e
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n")
      return "Exception communicating with Digital Ocean: #{e}"
    end
    return nil
  end

  def digital_ocean_delete_snapshot(remote_id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'
    end
    self.invalidate
    begin
      response = digital_ocean.image.destroy(remote_id)
      if !response.success?
        return "Error deleting Digital Ocean snapshot: #{response}"
      end
    rescue Faraday::Error => e
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n")
      return "Exception communicating with Digital Ocean: #{e}"
    end
    return nil
  end

  def digital_ocean_ssh_public_key(id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    response = nil
    begin
      response = digital_ocean.key.show(id)
      if !response.success?
        return "Error getting Digital Ocean SSH key: #{response}".error!
      end
    rescue Faraday::Error => e
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n")
      return "Exception communicating with Digital Ocean: #{e}".error!
    end
    return response.ssh_key.public_key
  end

  def digital_ocean_gamocosm_ssh_key_id
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    public_key = Gamocosm::DIGITAL_OCEAN_SSH_PUBLIC_KEY
    fingerprint = Gamocosm::DIGITAL_OCEAN_SSH_PUBLIC_KEY_FINGERPRINT
    self.invalidate_digital_ocean_cache_ssh_keys
    keys = self.digital_ocean_ssh_keys
    if keys.error?
      return keys
    end
    for x in keys
      if x.fingerprint == fingerprint
        return x.id
      end
    end
    return self.digital_ocean_add_ssh_key('gamocosm', public_key)
  end
end
