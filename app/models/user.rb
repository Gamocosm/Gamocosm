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
#  digital_ocean_event_id :integer
#

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :minecraft_servers, dependent: :destroy
  has_and_belongs_to_many :friend_minecraft_servers, foreign_key: 'user_id', class_name: 'MinecraftServer'

  def digital_ocean_missing?
    return digital_ocean_api_key.nil?
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

  def digital_ocean_snapshots
    if digital_ocean_invalid?
      return nil
    end
    response = digital_ocean.image.all
    if !response.success?
      return nil
    end
    # response.images is [#<Hashie::Mash action_ids=[26688497] created_at="2014-06-18T04:36:00Z" distribution="Fedora" id=4369683 name="gamocosm-minecraft-tfc-2" public=false regions=["nyc2"] slug=nil>, #<Hashie::Mash action_ids=[30088900] created_at="2014-08-04T04:20:24Z" distribution="Fedora" id=5460282 name="gamocosm-minecraft-uncharted-territories-3" public=false regions=["nyc2"] slug=nil>, #<Hashie::Mash action_ids=[30854415] created_at="2014-08-17T07:50:21Z" distribution="Fedora" id=5621836 name="gamocosm-minecraft-im-creative" public=false regions=["nyc2"] slug=nil>, #<Hashie::Mash action_ids=[31251098] created_at="2014-08-23T06:04:28Z" distribution="Fedora" id=5723493 name="gamocosm-minecraft-simulation-protocol" public=false regions=["nyc2"] slug=nil>, #<Hashie::Mash action_ids=[31352159] created_at="2014-08-25T04:51:40Z" distribution="Ubuntu" id=5766844 name="foo" public=false regions=["nyc2"] slug=nil>, #<Hashie::Mash action_ids=[31255424] created_at="2014-08-23T08:12:46Z" distribution="Fedora" id=5725451 name="gamocosm-minecraft-snapshot" public=false regions=["nyc3"] slug=nil>]
    return response.images.select { |x| !x.public }
  end

  def digital_ocean_snapshot_exists?(snapshot_id)
    if digital_ocean_invalid?
      return nil
    end
    return !digital_ocean_snapshots.index { |x| x.id == snapshot_id }.nil?
  end

  def digital_ocean_droplets
    if digital_ocean_invalid?
      return nil
    end
    return @digital_ocean_droplets.droplets
    # #<Barge::Response droplets=[#<Hashie::Mash action_ids=[31352159, 31352154, 31352074] backup_ids=[] created_at="2014-08-25T04:49:48Z" disk=20 features=["virtio"] id=2444491 image=#<Hashie::Mash action_ids=[29202525, 29203474, 29204856, 29204858, 29204860, 29204863, 29204865, 29204868, 29209875, 29209878, 29209902, 29209919, 29209926, 29209929, 29209954, 29209962, 29209964, 29209966, 29209997, 29209999, 29210003, 29210022, 29210030, 29210127, 29210135] created_at="2014-07-23T17:08:52Z" distribution="Ubuntu" id=5141286 name="Ubuntu 14.04 x64" public=true regions=["nyc1", "ams1", "sfo1", "nyc2", "ams2", "sgp1", "lon1", "nyc3"] slug="ubuntu-14-04-x64"> kernel=#<Hashie::Mash id=1682 name="* Ubuntu 14.04 x64 vmlinuz-3.13.0-32-generic" version="3.13.0-32-generic"> locked=false memory=512 name="foo" networks=#<Hashie::Mash v4=[#<Hashie::Mash gateway="162.243.57.1" ip_address="162.243.57.119" netmask="255.255.255.0" type="public">] v6=[]> region=#<Hashie::Mash available=true features=["virtio", "private_networking", "backups"] name="New York 2" sizes=["1gb", "2gb", "4gb", "8gb", "32gb", "64gb", "512mb", "16gb", "48gb"] slug="nyc2"> size=#<Hashie::Mash price_hourly=0.00744 price_monthly=5.0 slug="512mb" transfer=1> snapshot_ids=[5766844] status="active" vcpus=1>] meta=#<Hashie::Mash total=1>>
  end

  def digital_ocean_gamocosm_ssh_key_id
    if digital_ocean_invalid?
      return nil
    end
    for x in digital_ocean.key.all.ssh_keys
      if x.name == 'gamocosm'
        return x.id
      end
    end
    public_key = nil
    begin
      public_key = File.read(Gamocosm.digital_ocean_ssh_public_key_path).chomp
    rescue
      Rails.logger.warn "User#digital_ocean_gamocosm_ssh_key_id: exception #{e.message}"
      Rails.logger.warn e.backtrace.join("\n")
    end
    if public_key.nil?
      raise "Unable to get gamocosm ssh key"
    end
    response = digital_ocean.key.create(name: 'gamocosm', public_key: public_key)
    if response.success?
      return response.ssh_key.id
    end
    return nil
  end
end
