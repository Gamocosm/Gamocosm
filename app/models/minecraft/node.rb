class Minecraft::Node

  MCSW_PORT = 5000
  HTTP_REQUEST_TIMEOUT = 4

  def initialize(local_minecraft, ip_address)
    @local_minecraft = local_minecraft
    @ip_address = ip_address
    @port = MCSW_PORT
    @conn = Faraday.new(url: "http://#{@ip_address}:#{@port}") do |conn|
      conn.request :basic_auth, Gamocosm::MCSW_USERNAME, @local_minecraft.mcsw_password
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  def invalidate
    @pid = nil
  end

  def error?
    pid.error?
  end

  def num_players
    errors = []
    if @querier_status.nil?
      @querier_status = Minecraft::Ping.new(@ip_address)
    end
    n = @querier_status.players_online
    if !n.error?
      return n
    end
    errors.push(n)
    if @querier.nil?
      @querier = Minecraft::Querier.new(@ip_address)
    end
    n = @querier.read_num_players
    if !n.error?
      return n
    end
    errors.push(n)
    "Could not query Minecraft: #{errors}".error!(errors)
  end

  def pid
    silence do
      if @pid.nil?
        res = do_get(:pid)
        if res.error?
          @pid = res
          @local_minecraft.server.log("Error getting Minecraft pid: #{res}")
        else
          @pid = res['pid']
        end
      end
      return @pid
    end
  end

  def resume
    silence do
      res = do_post(:start, { ram: "#{@local_minecraft.server.ram}M" })
      invalidate
      if res.error?
        return res
      end
      return nil
    end
  end

  def pause
    silence do
      res = do_post(:stop, {}, 32)
      invalidate
      if res.error?
        return res
      end
      return nil
    end
  end

  def exec(command)
    silence do
      res = do_post(:exec, { command: })
      if res.error?
        return res
      end
      return nil
    end
  end

  def backup
    silence do
      res = do_post(:backup, {})
      if res.error?
        return res
      end
      return nil
    end
  end

  def properties
    silence do
      res = do_get(:minecraft_properties)
      if res.error?
        return res
      end
      return res['properties']
    end
  end

  def update_properties(properties)
    silence do
      payload = {}
      properties.each_pair do |k, v|
        payload[k.to_s.gsub('_', '-')] = v.to_s
      end
      res = do_post(:minecraft_properties, { properties: payload })
      if res.error?
        return res
      end
      return res['properties']
    end
  end

  private
  def do_get(endpoint)
    begin
      res = @conn.get do |req|
        req.url "/#{endpoint}"
        req.options.open_timeout = HTTP_REQUEST_TIMEOUT
        req.options.timeout = HTTP_REQUEST_TIMEOUT
      end
      parse_response(res, endpoint)
    rescue Faraday::Error => e
      msg = "MCSW API network exception: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      msg.error! e
    end
  end

  def do_post(endpoint, data, timeout = HTTP_REQUEST_TIMEOUT)
    begin
      res = @conn.post do |req|
        req.url "/#{endpoint}"
        req.options.open_timeout = timeout
        req.options.timeout = timeout
        req.headers['Content-Type'] = 'application/json'
        req.body = data.to_json
      end
      parse_response(res, endpoint)
    rescue Faraday::Error => e
      msg = "MCSW API network exception: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      msg.error! e
    end
  end

  def parse_response(res, endpoint)
    if res.status != 200
      msg = "MCSW API error: HTTP response code #{res.status}, #{res.body}"
      return msg.error! res
    end
    if !res.body['status'].nil?
      msg = "MCSW API error: action #{endpoint} response status not OK, was #{res.body['status']}, #{res.body}"
      return msg.error! res
    end
    res.body
  end
end
