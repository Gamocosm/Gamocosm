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
  end

  def digital_ocean_invalid?
    # checks digital ocean droplets
    return self.digital_ocean_missing? || self.digital_ocean_droplets.nil?
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
            Rails.cache.write(self.digital_ocean_servers_cache, droplets.map { |x| x.to_hash }, expires_in: 512.seconds)
          else
            droplets = false
          end
        rescue Faraday::TimeoutError
          droplets = false
        end
      else
        droplets = droplets.map { |x| Hashie::Mash.new(x) }
      end
      # cache the result for this request (if there was an error, don't keep trying)
      @digital_ocean_droplets = droplets
    end
    return @digital_ocean_droplets == false ? nil : @digital_ocean_droplets
  end

  def digital_ocean_snapshots
    # mostly parallel to User#digital_ocean_droplets
    # if we had an error getting the droplets, don't try to get the snapshots
    if digital_ocean_invalid?
      return nil
    end
    if @digital_ocean_snapshots.nil?
      snapshots = Rails.cache.read(self.digital_ocean_snapshots_cache)
      if snapshots.nil?
        begin
          response = self.digital_ocean.image.all
          if response.success?
            snapshots = response.images.select { |x| !x.public }
            Rails.cache.write(self.digital_ocean_snapshots_cache, snapshots.map { |x| x.to_hash }, expires_in: 512.seconds)
          else
            snapshots = false
          end
        rescue Faraday::TimeoutError
          snapshots = false
        end
      else
        snapshots = snapshots.map { |x| Hashie::Mash.new(x) }
      end
      @digital_ocean_snapshots = snapshots
    end
    return @digital_ocean_snapshots == false ? nil : @digital_ocean_snapshots
  end

  def digital_ocean_add_ssh_key(name, public_key)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'
    end
    begin
      response = digital_ocean.key.create(name: name, public_key: public_key)
    rescue
      return 'Timed out adding Digital Ocean SSH key'
    end
    if !response.success?
      return "Error adding Digital Ocean SSH key; they responded with #{response}"
    end
    return nil
  end

  def digital_ocean_delete_ssh_key(remote_id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'
    end
    begin
      response = digital_ocean.key.destroy(remote_id)
    rescue Faraday::TimeoutError
      return "Timed out deleting Digital Ocean SSH key #{remote_id}"
    end
    if !response.success?
      return "Error deleting Digital Ocean SSH key; they responded with #{response}"
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
    rescue Faraday::TimeoutError
      return "Timed out deleting Digital Ocean droplet #{remote_id}"
    end
    if !response.success?
      return "Error deleting Digital Ocean droplet; they responded with #{response}"
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
    rescue Faraday::TimeoutError
      return "Timed out deleting Digital Ocean snapshot #{remote_id}"
    end
    if !response.success?
      return "Error deleting Digital Ocean snapshot; they responded with #{response}"
    end
    return nil
  end

  def digital_ocean_ssh_public_key(id)
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    begin
      response = digital_ocean.key.show(id)
    rescue Faraday::TimeoutError
      return "Timed out getting Digital Ocean SSH key #{id}".error!
    end
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
      begin
        response = digital_ocean.key.all
      rescue Faraday::TimeoutError
        @digital_ocean_ssh_keys = false
        return nil
      end
      if !response.success?
        @digital_ocean_ssh_keys = false
      else
        @digital_ocean_ssh_keys = response.ssh_keys
      end
    end
    return @digital_ocean_ssh_keys == false ? nil : @digital_ocean_ssh_keys
  end

  def digital_ocean_gamocosm_ssh_key_id
    if digital_ocean_missing?
      return 'Digital Ocean API token missing'.error!
    end
    public_key = File.read(Gamocosm.digital_ocean_ssh_public_key_path)
    fingerprint = Digest::MD5.hexdigest(Base64.decode64(public_key.split(/\s+/m)[1])).scan(/../).join(':')
    begin
      keys = digital_ocean.key.all
    rescue Faraday::TimeoutError
      return "Unable to get keys; timed out getting data from Digital Ocean".error!
    end
    if !keys.success?
      return "Unable to get keys; Digital Ocean responded with #{keys}".error!
    end
    for x in keys.ssh_keys
      if x.fingerprint == fingerprint
        return x.id
      end
    end
    begin
      response = digital_ocean.key.create(name: 'gamocosm', public_key: public_key)
    rescue Farady::TimeoutError
      return "Unable to add key; Digital Ocean timed out".error!
    end
    if response.success?
      return response.ssh_key.id
    end
    return "Unable to add key; Digital Ocean responded with #{response}".error!
  end
end
