class CloudFlare::Client

  CLOUDFLARE_API_URL = 'https://api.cloudflare.com/client/v4/'
  HTTP_REQUEST_TIMEOUT = 4

  def initialize(api_email, api_token, domain, zone)
    @api_email = api_email
    @api_token = api_token
    @domain = domain
    @zone = zone
    @conn = Faraday.new(url: CLOUDFLARE_API_URL) do |conn|
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  def dns_list(name)
    silence do
      res = do_get("zones/#{@zone}/dns_records", name == nil ? {} : { name: "#{name}.#{Gamocosm::USER_SERVERS_DOMAIN}" })
      if res.error?
        return res
      end
      records = []
      res.each do |x|
        if x['type'] == 'A'
          records.push({ id: x['id'], name: x['name'], content: x['content']})
        end
      end
      return records
    end
  end

  def dns_add(name, ip)
    silence do
      self.dns_delete(name)
      res = do_post("zones/#{@zone}/dns_records", { type: 'A', name: name, content: ip, ttl: 120 })
      return res.error? ? res : nil
    end
  end

  def dns_delete(name)
    silence do
      records = self.dns_list(name)
      if records.error?
        return records
      end
      errors = []
      records.each do |x|
        res = do_delete("zones/#{@zone}/dns_records/#{x[:id]}")
        if res.error?
          errors.push(res)
        end
      end
      return errors.count == 0 ? nil : ("CloudFlare API error: had #{errors.count} errors deleting DNS records.".error! errors)
    end
  end

  private
  def update_headers(opts)
    opts['X-Auth-Key'] = @api_token
    opts['X-Auth-Email'] = @api_email
    opts['Content-Type'] = 'application/json'
  end

  def do_get(action, params)
    begin
      res = @conn.get do |req|
        req.url action, params
        update_headers(req.headers)
        req.options.open_timeout = HTTP_REQUEST_TIMEOUT
        req.options.timeout = HTTP_REQUEST_TIMEOUT
      end
      parse_response(res)
    rescue Faraday::Error => e
      msg = "CloudFlare API network exception: #{e}."
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      msg.error! e
    end
  end

  def do_post(action, params)
    begin
      res = @conn.post do |req|
        req.url action
        update_headers(req.headers)
        req.options.open_timeout = HTTP_REQUEST_TIMEOUT
        req.options.timeout = HTTP_REQUEST_TIMEOUT
        req.body = params.to_json
      end
      parse_response(res)
    rescue Faraday::Error => e
      msg = "CloudFlare API network exception: #{e}."
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      msg.error! e
    end
  end

  def do_delete(action)
    begin
      res = @conn.delete do |req|
        req.url action
        update_headers(req.headers)
        req.options.open_timeout = HTTP_REQUEST_TIMEOUT
        req.options.timeout = HTTP_REQUEST_TIMEOUT
      end
      parse_response(res)
    rescue Faraday::Error => e
      msg = "CloudFlare API network exception: #{e}."
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      msg.error! e
    end
  end

  def parse_response(res)
    if res.status != 200
      msg = "CloudFlare API error: HTTP response code #{res.status}, #{res.body}."
      Rails.logger.error msg
      return msg.error! res
    end
    if res.body['success'] != true
      msg = "CloudFlare API error: response result #{res.body}."
      Rails.logger.error msg
      return msg.error! res
    end
    res.body['result']
  end

end
