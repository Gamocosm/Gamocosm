class CloudFlare::Client
  include HTTParty
  default_timeout 4

  CLOUDFLARE_API_URL = 'https://www.cloudflare.com/api_json.html'

  def initialize(api_email, api_token, domain)
    @api_email = api_email
    @api_token = api_token
    @domain = domain
  end

  def make_post_params(a, opts)
    return {
      tkn: @api_token,
      email: @api_email,
      a: a,
      z: @domain
    }.merge(opts)
  end

  def list_dns
    response = self.parse_response(self.class.post(CLOUDFLARE_API_URL, { query: self.make_post_params('rec_load_all', {}) }))
    if response.error?
      return response
    end
    begin
      records = []
      response['recs']['objs'].each do |x|
        if x['type'] == 'A'
          records.push({ id: x['rec_id'].to_i, name: x['display_name'], content: x['content']})
        end
      end
      return records
    rescue Net::ReadTimeout => e
      Rails.logger.error "CloudFlare API read timeout: #{e}"
      Rails.logger.error e.backtrace.join("\n")
      return "Error with CloudFlare API; exception #{e}".error!
    rescue => e
      return "Error with CloudFlare API; exception #{e}".error!
    end
  end

  def add_dns(name, ip)
    begin
      response = self.parse_response(self.class.post(CLOUDFLARE_API_URL, { query: self.make_post_params('rec_new', { type: 'A', name: name, content: ip, ttl: 120 }) }))
      return response.error? ? response : nil
    rescue Net::ReadTimeout => e
      Rails.logger.error "CloudFlare API read timeout: #{e}"
      Rails.logger.error e.backtrace.join("\n")
      return "Error with CloudFlare API; exception #{e}".error!
    end
  end

  def update_dns(name, ip)
    begin
      records = self.list_dns
      if records.error?
        return records
      end
      x = records.index { |x| x[:name] == name }
      if x.nil?
        return self.add_dns(name, ip)
      end
      response = self.parse_response(self.class.post(CLOUDFLARE_API_URL, { query: self.make_post_params('rec_edit', { id: records[x][:id], type: 'A', name: name, content: ip, ttl: 120 }) }))
      return response.error? ? response : nil
    rescue Net::ReadTimeout => e
      Rails.logger.error "CloudFlare API read timeout: #{e}"
      Rails.logger.error e.backtrace.join("\n")
      return "Error with CloudFlare API; exception #{e}".error!
    end
  end

  def delete_dns(name)
    begin
      records = self.list_dns
      if records.error?
        return records
      end
      x = records.index { |x| x[:name] == name }
      if x.nil?
        return nil
      end
      response = self.parse_response(self.class.post(CLOUDFLARE_API_URL, { query: self.make_post_params('rec_delete', { id: records[x][:id] }) }))
      return response.error? ? response : nil
    rescue Net::ReadTimeout => e
      Rails.logger.error "CloudFlare API read timeout: #{e}"
      Rails.logger.error e.backtrace.join("\n")
      return "Error with CloudFlare API; exception #{e}".error!
    end
  end

  def parse_response(res)
    if res.code != 200
      return "Error with CloudFlare API; HTTP response code was #{res.code}".error!
    end
    if res.parsed_response['result'] != 'success'
      Rails.logger.error "CloudFlare error; response was #{res}"
      return "Error with CloudFlare API; response result was #{res.parsed_response['result']}".error!
    end
    return res.parsed_response['response']
  end
end
