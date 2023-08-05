# https://docs.digitalocean.com/reference/api/api-reference/
module DigitalOcean
  Droplet = Struct.new(:id, :name, :created_at, :memory, :status, :snapshot_ids, :ipv4)

  Image = Struct.new(:id, :name, :created_at)

  SSHKey = Struct.new(:id, :name, :fingerprint, :public_key)

  Action = Struct.new(:id, :status) do
    def done?
      status == 'completed'
    end

    def failed?
      status == 'errored'
    end
  end

  Size = Struct.new(:slug, :name, :memory, :disk, :cpu, :price_hourly, :price_monthly, :description) do
    def price
      "#{(price_hourly * 100).round(1)} cents/hour"
    end

    def descriptor
      "#{description} (CPUs: #{cpu}, Memory: #{memory / 1024} GB, Disk: #{disk} GB) at #{price} (#{slug})"
    end
  end

  Region = Struct.new(:slug, :name, :available)

  Volume = Struct.new(:id, :name, :created_at, :size_gb, :region)

  Snapshot = Struct.new(:id, :name, :created_at, :min_disk_size, :regions)

  DEFAULTS = JSON.load_file(File.expand_path('config/digital_ocean_defaults.json', Rails.root), symbolize_names: true)

  DEFAULT_REGIONS = DEFAULTS[:regions].map { |x| Region.new(*x) }
  DEFAULT_SIZES = DEFAULTS[:sizes].map { |x| Size.new(*x) }

  class Connection
    attr_reader :con

    API_URL = 'https://api.digitalocean.com/v2'
    PER_PAGE = 200
    OPEN_TIMEOUT = 32
    TIMEOUT = 64

    def initialize(api_key)
      @con = DropletKit::Client.new(access_token: api_key, open_timeout: OPEN_TIMEOUT, timeout: TIMEOUT)
    end

    def silence_digital_ocean_api(is_delete = false, &block)
      if @con.access_token.nil?
        return 'You have not entered your Digital Ocean API token'.error!(nil)
      end
      silence do
        begin
          return block.call
        rescue DropletKit::HttpStatusError => e
          if e.status == 401
            msg = "Unable to authenticate your Digital Ocean API token: #{e}"
            return msg.error! e
          end
          if is_delete && e.status == 404
            return nil
          end
          msg = "Digital Ocean API HTTP response status not ok: #{e}"
          return msg.error! e
        rescue DropletKit::Error => e
          msg = "Digital Ocean API error: #{e}"
          return msg.error! e
        end
      end
    end

    def droplet_list
      silence_digital_ocean_api do
        res = @con.droplets.all
        res.map { |x| self.class.droplet_from_response(x) }
      end
    end

    def droplet_show(id)
      silence_digital_ocean_api do
        res = @con.droplets.find(id:)
        self.class.droplet_from_response(res)
      end
    end

    def droplet_action_list(id)
      silence_digital_ocean_api do
        res = @con.droplets.actions(id:)
        arr = res.map { |x| self.class.action_from_response(x) }
        arr.sort_by!(&:id)
        arr
      end
    end

    def droplet_create(name, region, size, image, ssh_keys, volumes)
      silence_digital_ocean_api do
        droplet = DropletKit::Droplet.new(
          name:,
          region:,
          size:,
          image:,
          ssh_keys:,
          volumes:,
        )
        res = @con.droplets.create(droplet)
        self.class.droplet_from_response(res)
      end
    end

    def droplet_snapshot(id, name)
      silence_digital_ocean_api do
        action = @con.droplet_actions.snapshot(droplet_id: id, name:)
        self.class.action_from_response(action)
      end
    end

    def droplet_delete(id)
      silence_digital_ocean_api(true) do
        @con.droplets.delete(id:)
        nil
      end
    end

    def droplet_shutdown(id)
      silence_digital_ocean_api do
        action = @con.droplet_actions.shutdown(droplet_id: id)
        self.class.action_from_response(action)
      end
    end

    def droplet_reboot(id)
      silence_digital_ocean_api do
        action = @con.droplet_actions.reboot(droplet_id: id)
        self.class.action_from_response(action)
      end
    end

    def droplet_action_show(droplet_id, action_id)
      silence_digital_ocean_api do
        action = @con.droplet_actions.find(droplet_id:, id: action_id)
        self.class.action_from_response(action)
      end
    end

    def image_list
      silence_digital_ocean_api do
        res = @con.images.all(private: true)
        res.map { |x| self.class.image_from_response(x) }
      end
    end

    def image_delete(id)
      silence_digital_ocean_api(true) do
        @con.images.delete(id:)
        nil
      end
    end

    def ssh_key_list
      silence_digital_ocean_api do
        res = @con.ssh_keys.all
        res.map { |x| self.class.ssh_key_from_response(x) }
      end
    end

    def ssh_key_show(id)
      silence_digital_ocean_api do
        res = @con.ssh_keys.find(id:)
        self.class.ssh_key_from_response(res)
      end
    end

    def ssh_key_create(name, public_key)
      silence_digital_ocean_api do
        key = DropletKit::SSHKey.new(
          name:,
          public_key:,
        )
        res = @con.ssh_keys.create(key)
        self.class.ssh_key_from_response(res)
      end
    end

    def ssh_key_delete(id)
      silence_digital_ocean_api(true) do
        @con.ssh_keys.delete(id:)
        nil
      end
    end

    def region_list_uncached
      silence_digital_ocean_api do
        res = @con.regions.all
        arr = res.map { |x| self.class.region_from_response(x) }
        arr.select!(&:available)
        arr.sort_by!(&:slug)
        arr
      end
    end

    def size_list_uncached
      silence_digital_ocean_api do
        res = @con.sizes.all
        arr = res.map { |x| self.class.size_from_response(x) }
        # Fedora image needs at least 15 GB
        arr.select! { |x| x.disk > 15 }
        # We're in the 21st century
        arr.select! { |x| x.memory >= 1024 }
        # No fat cats here
        arr.select! { |x| x.price_monthly < 100 }
        arr.sort_by!(&:price_monthly)
        arr
      end
    end

    def region_list
      if @regions.nil?
        res = region_list_uncached
        if res.error?
          Rails.logger.error "Unable to get Digital Ocean regions in #{self.class}: #{res}"
          @regions = DigitalOcean::DEFAULT_REGIONS
        else
          @regions = res
        end
      end
      @regions
    end

    def size_list
      if @sizes.nil?
        res = size_list_uncached
        if res.error?
          Rails.logger.error "Unable to get Digital Ocean sizes in #{self.class}: #{res}"
          @sizes = DigitalOcean::DEFAULT_SIZES
        else
          @sizes = res
        end
      end
      @sizes
    end

    def region_find(slug)
      region_list.select { |x| x.slug == slug }.first
    end

    def size_find(slug)
      size_list.select { |x| x.slug == slug }.first
    end

    def volume_list
      silence_digital_ocean_api do
        res = @con.volumes.all
        res.map { |x| self.class.volume_from_response(x) }
      end
    end

    def volume_show(id)
      silence_digital_ocean_api do
        res = @con.volumes.find(id:)
        self.class.volume_from_response(res)
      end
    end

    def volume_create(name, size, region, snapshot_id)
      silence_digital_ocean_api do
        args = {
          name:,
          size_gigabytes: size,
          region:,
        }
        if snapshot_id.nil?
          args[:filesystem_type] = 'ext4'
        else
          args[:snapshot_id] = snapshot_id
        end
        volume = DropletKit::Volume.new(args)
        res = @con.volumes.create(volume)
        self.class.volume_from_response(res)
      end
    end

    def volume_delete(id)
      silence_digital_ocean_api(true) do
        @con.volumes.delete(id:)
        nil
      end
    end

    def volume_snapshot(id, name)
      silence_digital_ocean_api do
        res = @con.volumes.create_snapshot(id:, name:)
        self.class.snapshot_from_response(res)
      end
    end

    def snapshot_list
      silence_digital_ocean_api do
        res = @con.snapshots.all(resource_type: 'volume')
        res.map { |x| self.class.snapshot_from_response(x) }
      end
    end

    def snapshot_show(id)
      silence_digital_ocean_api do
        res = @con.snapshots.find(id:)
        self.class.snapshot_from_response(res)
      end
    end

    def snapshot_delete(id)
      silence_digital_ocean_api(true) do
        @con.snapshots.delete(id:)
        nil
      end
    end

    def self.droplet_from_response(res)
      Droplet.new(
        res.id,
        res.name,
        res.created_at,
        res.memory,
        res.status,
        res.snapshot_ids.sort,
        res.networks.v4.try(:select) { |x| x.type == 'public' }.try(:first).try(:ip_address),
      )
    end

    def self.image_from_response(res)
      Image.new(res.id, res.name, res.created_at)
    end

    def self.action_from_response(res)
      Action.new(res.id, res.status)
    end

    def self.ssh_key_from_response(res)
      SSHKey.new(res.id, res.name, res.fingerprint, res.public_key)
    end

    def self.size_from_response(res)
      Size.new(res.slug, res.slug.upcase, res.memory, res.disk, res.vcpus, res.price_hourly, res.price_monthly, res.description)
    end

    def self.region_from_response(res)
      Region.new(res.slug, res.name, res.available)
    end

    def self.volume_from_response(res)
      Volume.new(res.id, res.name, res.created_at, res.size_gigabytes, res.region.slug)
    end

    def self.snapshot_from_response(res)
      Snapshot.new(res.id, res.name, res.created_at, res.min_disk_size, res.regions)
    end
  end
end
