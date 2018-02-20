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

  def dns_list
    silence do
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
    end
  end

  def dns_add(name, ip)
    silence do
      res = do_request(:rec_new, { type: 'A', name: name, content: ip, ttl: 120 })
      return res.error? ? res : nil
    end
  end

  def dns_update(name, ip)
    silence do
=begin
      records = self.dns_list
      if records.error?
        return records
      end
      x = records.index { |x| x[:name] == name }
      if x.nil?
        return self.dns_add(name, ip)
      end
=end
      error = self.dns_add(name, ip)
      if !error.nil?
        if error.data.body['msg'] != 'The record already exists.'
          return error
        end
      end
      res = do_request(:rec_edit, { id: records[x][:id], type: 'A', name: name, content: ip, ttl: 120 })
      return res.error? ? res : nil
    end
  end

  def dns_delete(name)
    silence do
      records = self.dns_list
      if records.error?
        return records
      end
      x = records.index { |x| x[:name] == name }
      if x.nil?
        return nil
      end
      res = do_request(:rec_delete, { id: records[x][:id] })
      return res.error? ? res : nil
    end
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
      msg = "CloudFlare API network exception: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      return msg.error! e
    end
  end

  def parse_response(res)
    if res.status != 200
      msg = "CloudFlare API error: HTTP response code #{res.status}, #{res.body}"
      Rails.logger.error msg
      return msg.error! res
    end
    if res.body['result'] != 'success'
      msg = "CloudFlare API error: response result #{res.body['result']}, #{res.body}"
      Rails.logger.error msg
      return msg.error! res
    end
    return res.body['response']
  end

end
