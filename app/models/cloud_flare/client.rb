class CloudFlare::Client

  CLOUDFLARE_API_URL = 'https://www.cloudflare.com/api_json.html'
  HTTP_REQUEST_TIMEOUT = 4

  def initialize(api_email, api_token, domain)
    @api_email = api_email
    @api_token = api_token
    @domain = domain
    @conn = Faraday.new(url: CLOUDFLARE_API_URL) do |conn|
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  def list_dns
    response = do_request(:rec_load_all, {})
    if response.error?
      return response
    end
    records = []
    response['recs']['objs'].each do |x|
      if x['type'] == 'A'
        records.push({ id: x['rec_id'].to_i, name: x['display_name'], content: x['content']})
      end
    end
    return records
  rescue => e
    msg = "Badness in #{self.class}: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    ExceptionNotifier.notify_exception(e)
    return msg.error!
  end

  def add_dns(name, ip)
    res = do_request(:rec_new, { type: 'A', name: name, content: ip, ttl: 120 })
    return res.error? ? res : nil
  rescue => e
    msg = "Badness in #{self.class}: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    ExceptionNotifier.notify_exception(e)
    return msg.error!
  end

  def update_dns(name, ip)
    records = self.list_dns
    if records.error?
      return records
    end
    x = records.index { |x| x[:name] == name }
    if x.nil?
      return self.add_dns(name, ip)
    end
    res = do_request(:rec_edit, { id: records[x][:id], type: 'A', name: name, content: ip, ttl: 120 })
    return res.error? ? res : nil
  rescue => e
    msg = "Badness in #{self.class}: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    ExceptionNotifier.notify_exception(e)
    return msg.error!
  end

  def delete_dns(name)
    records = self.list_dns
    if records.error?
      return records
    end
    x = records.index { |x| x[:name] == name }
    if x.nil?
      return nil
    end
    res = do_request(:rec_delete, { id: records[x][:id] })
    return res.error? ? res : nil
  rescue => e
    msg = "Badness in #{self.class}: #{e}"
    Rails.logger.error msg
    Rails.logger.error e.backtrace.join("\n")
    ExceptionNotifier.notify_exception(e)
    return msg.error!
  end

  private
  def do_request(action, data)
    return do_post(make_post_params(action, data))
  end

  def make_post_params(a, opts)
    return {
      tkn: @api_token,
      email: @api_email,
      a: a.to_s,
      z: @domain
    }.merge(opts)
  end

  def do_post(params)
    begin
      res = @conn.post do |req|
        req.params = params
        req.options.timeout = HTTP_REQUEST_TIMEOUT
      end
      return parse_response(res)
    rescue Faraday::Error => e
      msg = "CloudFlare API exception: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      return msg.error!
    end
  end

  def parse_response(res)
    if res.status != 200
      msg = "CloudFlare API error: HTTP response code #{res.status}, #{res.body}"
      Rails.logger.error msg
      return msg.error!
    end
    if res.body['result'] != 'success'
      msg = "CloudFlare API error: response result #{res.body['result']}, #{res.body}"
      Rails.logger.error msg
      return msg.error!
    end
    return res.body['response']
  end

end
