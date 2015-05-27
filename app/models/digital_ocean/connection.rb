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

  class Size < Struct.new(:slug, :name, :memory, :disk, :cpu, :price_hourly, :price_monthly)
    DEFAULT_SIZES = [
      { price_hourly: 0.00744, price_monthly: 5.0, cpu: 1, disk: 20, memory: 512, name: '512MB', slug: '512mb' },
      { price_hourly: 0.01488, price_monthly: 10.0, cpu: 1, disk: 30, memory: 1024, name: '1GB', slug: '1gb' },
      { price_hourly: 0.02976, price_monthly: 20.0, cpu: 2, disk: 40, memory: 2048, name: '2GB', slug: '2gb' },
      { price_hourly: 0.05952, price_monthly: 40.0, cpu: 2, disk: 60, memory: 4096, name: '4GB', slug: '4gb' },
      { price_hourly: 0.11905, price_monthly: 80.0, cpu: 4, disk: 80, memory: 8192, name: '8GB', slug: '8gb' },
      { price_hourly: 0.2381, price_monthly: 160.0, cpu: 8, disk: 160, memory: 16384, name: '16GB', slug: '16gb' },
      { price_hourly: 0.47619, price_monthly: 320.0, cpu: 12, disk: 320, memory: 32768, name: '32GB', slug: '32gb' },
      { price_hourly: 0.71429, price_monthly: 480.0, cpu: 16, disk: 480, memory: 49152, name: '48GB', slug: '48gb' },
      { price_hourly: 0.95238, price_monthly: 640.0, cpu: 20, disk: 640, memory: 65536, name: '64GB', slug: '64gb' }
    ].map do |x|
      Size.new(x[:slug], x[:name], x[:memory], x[:disk], x[:cpu], x[:price_hourly], x[:price_monthly])
    end
    def price
      "#{(price_hourly * 100).round(1)} cents/hour"
    end
    def descriptor
      "#{name} at #{price} (up to $#{price_monthly}/month)"
    end
  end

  class Region < Struct.new(:slug, :name, :available)
    DEFAULT_REGIONS = [
      { name: 'New York 3', slug: 'nyc3' },
      { name: 'Amsterdam 3', slug: 'ams3' },
      { name: 'New York 2', slug: 'nyc2' },
      { name: 'Amsterdam 2', slug: 'ams2' },
      { name: 'San Francisco 1', slug: 'sfo1' },
      { name: 'London 1', slug: 'lon1' },
      { name: 'Singapore 1', slug: 'sgp1' },
    ].map { |x| Region.new(x[:slug], x[:name], true) }
  end

  class Connection
    API_URL = 'https://api.digitalocean.com/v2'
    PER_PAGE = 200
    HTTP_REQUEST_TIMEOUT = 16
    def initialize(api_key)
      @con = api_key.nil? ? nil : Faraday.new({
        url: API_URL,
        headers: {
          authorization: "Bearer #{api_key}",
          content_type: 'application/json',
        },
      }) do |f|
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def droplet_list
      silence do
        res = do_get('droplets')
        if res.error?
          return res
        end
        res['droplets'].map { |x| self.class.droplet_from_response(x) }
      end
    end

    def droplet_show(id)
      silence do
        res = do_get("droplets/#{id}")
        if res.error?
          return res
        end
        self.class.droplet_from_response(res['droplet'])
      end
    end

    def droplet_action_list(id)
      silence do
        res = do_get("droplets/#{id}/actions")
        if res.error?
          return res
        end
        res['actions'].map { |x| self.class.action_from_response(x) }.sort { |a, b| a.id <=> b.id }
      end
    end

    def droplet_create(name, region, size, image, ssh_keys)
      silence do
        res = do_post('droplets', {
          name: name,
          region: region,
          size: size,
          image: image,
          ssh_keys: ssh_keys.map { |x| x.to_s },
        })
        if res.error?
          return res
        end
        self.class.droplet_from_response(res['droplet'])
      end
    end

    def droplet_snapshot(id, name)
      silence do
        res = do_droplet_action(id, 'snapshot', { name: name })
        if res.error?
          return res
        end
        self.class.action_from_response(res['action'])
      end
    end

    def droplet_delete(id)
      silence do
        res = do_delete("droplets/#{id}")
        if res.error?
          return res
        end
        nil
      end
    end

    def droplet_shutdown(id)
      silence do
        res = do_droplet_action(id, 'shutdown', {})
        if res.error?
          return res
        end
        self.class.action_from_response(res['action'])
      end
    end

    def droplet_reboot(id)
      silence do
        res = do_droplet_action(id, 'reboot', {})
        if res.error?
          return res
        end
        self.class.action_from_response(res['action'])
      end
    end
=begin
    def droplet_power_on(id)
      silence do
        res = do_droplet_action(id, 'power_on', {})
        if res.error?
          return res
        end
        self.class.action_from_response(res['action'])
      end
    end
=end
    def droplet_action_show(droplet_id, action_id)
      silence do
        res = do_get("droplets/#{droplet_id}/actions/#{action_id}")
        if res.error?
          return res
        end
        self.class.action_from_response(res['action'])
      end
    end

    def image_list(private_only = true)
      silence do
        res = do_get('images', { private: private_only })
        if res.error?
          return res
        end
        res['images'].map { |x| self.class.image_from_response(x) }
      end
    end

    def image_delete(id)
      silence do
        res = do_delete("images/#{id}")
        if res.error?
          return res
        end
        nil
      end
    end

    def ssh_key_list
      silence do
        res = do_get('account/keys')
        if res.error?
          return res
        end
        res['ssh_keys'].map { |x| self.class.ssh_key_from_response(x) }
      end
    end

    def ssh_key_show(id)
      silence do
        res = do_get("account/keys/#{id}")
        if res.error?
          return res
        end
        self.class.ssh_key_from_response(res['ssh_key'])
      end
    end

    def ssh_key_create(name, public_key)
      silence do
        res = do_post('account/keys', { name: name, public_key: public_key })
        if res.error?
          return res
        end
        self.class.ssh_key_from_response(res['ssh_key'])
      end
    end

    def ssh_key_delete(id)
      silence do
        res = do_delete("account/keys/#{id}")
        if res.error?
          return res
        end
        nil
      end
    end

    def region_list_uncached
      silence do
        res = do_get('regions')
        if res.error?
          return res
        end
        res['regions'].map { |x| self.class.region_from_response(x) }.sort do |a, b|
          a_tier = a.slug[-1].to_i
          b_tier = b.slug[-1].to_i
          a_tier == b_tier ? b.slug <=> a.slug : b_tier <=> a_tier
        end
      end
    end

    def size_list_uncached
      silence do
        res = do_get('sizes')
        if res.error?
          return res
        end
        res['sizes'].map { |x| self.class.size_from_response(x) }
      end
    end

    def region_list
      if @regions.nil?
        res = region_list_uncached
        if res.error?
          Rails.logger.error "Unable to get Digital Ocean regions in #{self.class}: #{res}"
          @regions = DigitalOcean::Region::DEFAULT_REGIONS
        else
          @regions = res.select { |x| x.available }
        end
      end
      return @regions
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
      return @sizes
    end

    def region_find(slug)
      for x in region_list
        if x.slug == slug
          return x
        end
      end
      return nil
    end

    def size_find(slug)
      for x in size_list
        if x.slug == slug
          return x
        end
      end
      return nil
    end

    private
    def do_droplet_action(droplet_id, action, body)
      do_post("droplets/#{droplet_id}/actions", { type: action }.merge(body))
    end

    def do_get(endpoint, query = {})
      make_request(:get, endpoint, query.merge({ per_page: PER_PAGE }), nil)
    end

    def do_post(endpoint, body)
      make_request(:post, endpoint, nil, body)
    end

    def do_delete(endpoint)
      make_request(:delete, endpoint, nil, nil)
    end

    def make_request(verb, endpoint, query, body)
      if @con.nil?
        return 'You have not entered your Digital Ocean API token'.error! nil
      end
      begin
        res = case verb
        when :get
          @con.get do |req|
            req.url endpoint
            req.params = query
            req.options.timeout = HTTP_REQUEST_TIMEOUT
          end
        when :post
          @con.post do |req|
            req.url endpoint
            req.body = body.to_json
            req.options.timeout = HTTP_REQUEST_TIMEOUT
          end
        when :delete
          @con.delete do |req|
            req.url endpoint
            req.options.timeout = HTTP_REQUEST_TIMEOUT
          end
        else
          raise ArgumentError, "Bad HTTP method #{verb}"
        end
        if res.status == 401
          msg = "Unable to authenticate your Digital Ocean API token"
          return msg.error! nil
        elsif res.status / 100 == 2
          return res.body
        else
          msg = "Digital Ocean API error: HTTP response status not ok, was #{res.status}, #{res.inspect}"
          Rails.logger.error msg
          return msg.error! res
        end
      rescue Faraday::Error => e
        msg = "Digital Ocean API network exception: #{e}"
        Rails.logger.error msg
        Rails.logger.error e.backtrace.join("\n")
        return msg.error! e
      end
    end

    def self.droplet_from_response(res)
      Droplet.new(res['id'],
        res['name'],
        res['created_at'],
        res['memory'],
        res['status'],
        res['snapshot_ids'].sort,
        res['networks']['v4'].try(:select) { |x| x['type'] == 'public' }.try(:first).try(:[], 'ip_address'),
      )
    end

    def self.image_from_response(res)
      Image.new(res['id'], res['name'], res['created_at'])
    end

    def self.action_from_response(res)
      Action.new(res['id'], res['status'])
    end

    def self.ssh_key_from_response(res)
      SSHKey.new(res['id'], res['name'], res['fingerprint'], res['public_key'])
    end

    def self.size_from_response(res)
      Size.new(res['slug'], res['slug'].upcase, res['memory'], res['disk'], res['vcpus'], res['price_hourly'], res['price_monthly'])
    end

    def self.region_from_response(res)
      Region.new(res['slug'], res['name'], res['available'])
    end
  end
end
