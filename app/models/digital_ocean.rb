# Re-indent in vim with `gg=G`
# rubocop --autocorrect --only Style/HashSyntax,Style/StringLiterals,Layout/SpaceInsideHashLiteralBraces,Style/TrailingCommaInArrayLiteral app/models/digital_ocean.rb

module DigitalOcean
  class Droplet < Struct.new(:id, :name, :created_at, :memory, :status, :snapshot_ids, :ipv4)
  end

  class Image < Struct.new(:id, :name, :created_at)
  end

  class SSHKey < Struct.new(:id, :name, :fingerprint, :public_key)
  end

  class Action < Struct.new(:id, :status)
    def done?
      status == 'completed'
    end

    def failed?
      status == 'errored'
    end
  end

  class Size < Struct.new(:slug, :name, :memory, :disk, :cpu, :price_hourly, :price_monthly, :description)
    # Run `Gamocosm.digital_ocean.size_list_uncached.map(&:to_h)` to generate this list.
    DEFAULT_SIZES = [{ slug: 's-1vcpu-1gb', name: 'S-1VCPU-1GB', memory: 1024, disk: 25, cpu: 1, price_hourly: 0.00893, price_monthly: 6.0, description: 'Basic' },
                     { slug: 's-1vcpu-1gb-amd', name: 'S-1VCPU-1GB-AMD', memory: 1024, disk: 25, cpu: 1, price_hourly: 0.01042, price_monthly: 7.0, description: 'Basic AMD' },
                     { slug: 's-1vcpu-1gb-intel', name: 'S-1VCPU-1GB-INTEL', memory: 1024, disk: 25, cpu: 1, price_hourly: 0.01042, price_monthly: 7.0, description: 'Basic Intel' },
                     { slug: 's-1vcpu-2gb', name: 'S-1VCPU-2GB', memory: 2048, disk: 50, cpu: 1, price_hourly: 0.01786, price_monthly: 12.0, description: 'Basic' },
                     { slug: 's-1vcpu-2gb-amd', name: 'S-1VCPU-2GB-AMD', memory: 2048, disk: 50, cpu: 1, price_hourly: 0.02083, price_monthly: 14.0, description: 'Basic AMD' },
                     { slug: 's-1vcpu-2gb-intel', name: 'S-1VCPU-2GB-INTEL', memory: 2048, disk: 50, cpu: 1, price_hourly: 0.02083, price_monthly: 14.0, description: 'Basic Intel' },
                     { slug: 's-2vcpu-2gb', name: 'S-2VCPU-2GB', memory: 2048, disk: 60, cpu: 2, price_hourly: 0.02679, price_monthly: 18.0, description: 'Basic' },
                     { slug: 's-2vcpu-2gb-amd', name: 'S-2VCPU-2GB-AMD', memory: 2048, disk: 60, cpu: 2, price_hourly: 0.03125, price_monthly: 21.0, description: 'Basic AMD' },
                     { slug: 's-2vcpu-2gb-intel', name: 'S-2VCPU-2GB-INTEL', memory: 2048, disk: 60, cpu: 2, price_hourly: 0.03125, price_monthly: 21.0, description: 'Basic Intel' },
                     { slug: 's-2vcpu-4gb', name: 'S-2VCPU-4GB', memory: 4096, disk: 80, cpu: 2, price_hourly: 0.03571, price_monthly: 24.0, description: 'Basic' },
                     { slug: 's-2vcpu-4gb-amd', name: 'S-2VCPU-4GB-AMD', memory: 4096, disk: 80, cpu: 2, price_hourly: 0.04167, price_monthly: 28.0, description: 'Basic AMD' },
                     { slug: 's-2vcpu-4gb-intel', name: 'S-2VCPU-4GB-INTEL', memory: 4096, disk: 80, cpu: 2, price_hourly: 0.04167, price_monthly: 28.0, description: 'Basic Intel' },
                     { slug: 'c-2', name: 'C-2', memory: 4096, disk: 25, cpu: 2, price_hourly: 0.0625, price_monthly: 42.0, description: 'CPU-Optimized' },
                     { slug: 'c2-2vcpu-4gb', name: 'C2-2VCPU-4GB', memory: 4096, disk: 50, cpu: 2, price_hourly: 0.06994, price_monthly: 47.0, description: 'CPU-Optimized 2x SSD' },
                     { slug: 's-4vcpu-8gb', name: 'S-4VCPU-8GB', memory: 8192, disk: 160, cpu: 4, price_hourly: 0.07143, price_monthly: 48.0, description: 'Basic' },]
      .map do |x|
        Size.new(x[:slug], x[:name], x[:memory], x[:disk], x[:cpu], x[:price_hourly], x[:price_monthly])
      end

    def price
      "#{(price_hourly * 100).round(1)} cents/hour"
    end

    def descriptor
      "#{description} (CPUs: #{cpu}, Memory: #{memory / 1024} GB, Disk: #{disk} GB) at #{price} (#{slug})"
    end
  end

  class Region < Struct.new(:slug, :name, :available)
    # Run `Gamocosm.digital_ocean.region_list_uncached.map(&:to_h)` to generate this list.
    DEFAULT_REGIONS = [{ slug: 'ams3', name: 'Amsterdam 3', available: true },
                       { slug: 'blr1', name: 'Bangalore 1', available: true },
                       { slug: 'fra1', name: 'Frankfurt 1', available: true },
                       { slug: 'lon1', name: 'London 1', available: true },
                       { slug: 'nyc1', name: 'New York 1', available: true },
                       { slug: 'nyc3', name: 'New York 3', available: true },
                       { slug: 'sfo2', name: 'San Francisco 2', available: true },
                       { slug: 'sfo3', name: 'San Francisco 3', available: true },
                       { slug: 'sgp1', name: 'Singapore 1', available: true },
                       { slug: 'syd1', name: 'Sydney 1', available: true },
                       { slug: 'tor1', name: 'Toronto 1', available: true },]
      .map { |x| Region.new(x[:slug], x[:name], true) }
  end

  class Volume < Struct.new(:id, :name, :created_at, :size, :region)
  end

  class Snapshot < Struct.new(:id, :name, :created_at, :min_disk_size, :regions)
  end

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
        res.map { |x| self.class.action_from_response(x) }.sort { |a, b| a.id <=> b.id }
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

    def image_list(private_only = true)
      silence_digital_ocean_api do
        res = @con.images.all(private: private_only)
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
          @regions = DigitalOcean::Region::DEFAULT_REGIONS
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
          @sizes = DigitalOcean::Size::DEFAULT_SIZES
        else
          @sizes = res
        end
      end
      @sizes
    end

    def region_find(slug)
      for x in region_list
        if x.slug == slug
          return x
        end
      end
      nil
    end

    def size_find(slug)
      for x in size_list
        if x.slug == slug
          return x
        end
      end
      for x in Size::DEFAULT_SIZES
        if x.slug == slug
          return x
        end
      end
      nil
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
        res = @con.snapshots.all
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
