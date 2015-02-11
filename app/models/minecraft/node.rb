class Minecraft::Node

  MCSW_PORT = 5000
  HTTP_REQUEST_TIMEOUT = 4

  def initialize(local_minecraft, ip_address)
    @local_minecraft = local_minecraft
    @ip_address = ip_address
    @port = MCSW_PORT
    @conn = Faraday.new(url: "http://#{@ip_address}:#{@port}") do |conn|
      conn.response :json
      conn.basic_auth(Gamocosm::MCSW_USERNAME, @local_minecraft.minecraft_wrapper_password)
      conn.adapter Faraday.default_adapter
    end
  end

  def invalidate
    @pid = nil
  end

  def error?
    return pid.error?
  end

  def pid
    if @pid.nil?
      response = do_get(:pid)
      if response.error?
        @pid = response
        @local_minecraft.log("Error getting Minecraft pid: #{response}")
      else
        @pid = response['pid']
      end
    end
    return @pid
  end

  def resume
    response = do_post(:start, { ram: "#{@local_minecraft.server.ram}M" }, { timeout: 8 })
    invalidate
    if response.error?
      return response
    end
    return nil
  end

  def pause
    response = do_get(:stop)
    invalidate
    if response.error?
      return response
    end
    return nil
  end

  def exec(command)
    response = do_post(:exec, { command: command })
    if response.error?
      return response
    end
    return nil
  end

  def backup
    response = do_post(:backup, {})
    if response.error?
      return response
    end
    return nil
  end

  def properties
    response = do_get(:minecraft_properties)
    if response.error?
      return response
    end
    return response['properties']
  end

  def update_properties(properties)
    payload = {}
    properties.each_pair do |k, v|
      payload[k.to_s.gsub('_', '-')] = v.to_s
    end
    response = do_post(:minecraft_properties, { properties: payload })
    if response.error?
      return response
    end
    return response['properties']
  end

  def do_get(endpoint)
    begin
      res = @conn.get do |req|
        req.url "/#{endpoint}"
        req.options.timeout = HTTP_REQUEST_TIMEOUT
      end
      return parse_response(res, endpoint)
    rescue Faraday::Error => e
      msg = "MCSW API exception: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      return msg.error!
    end
  end

  def do_post(endpoint, data, options = {})
    begin
      res = @conn.post do |req|
        req.url "/#{endpoint}"
        req.options.timeout = HTTP_REQUEST_TIMEOUT
        req.headers['Content-Type'] = 'application/json'
        req.body = data.to_json
      end
      return parse_response(res, endpoint)
    rescue Faraday::Error => e
      msg = "MCSW API exception: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      return msg.error!
    end
  end

  def parse_response(res, endpoint)
    if res.status != 200
      msg = "MCSW API error: HTTP response code #{res.status}, #{res.body}"
      return msg.error!
    end
    if !res.body['status'].nil?
      msg = "MCSW API error: action #{endpoint} response status not OK, was #{res.body['status']}, #{res.body}"
      return msg.error!
    end
    return res.body
  end
end
