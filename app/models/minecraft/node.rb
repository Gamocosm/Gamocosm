class Minecraft::Node
  include HTTParty
  default_timeout 2

  def initialize(local_minecraft, ip_address, port = '5000')
    @local_minecraft = local_minecraft
    @ip_address = ip_address
    @port = port
    @options = {
      headers: {
        'User-Agent' => 'Gamocosm',
        'Content-Type' => 'application/json'
      },
      basic_auth: {
        username: Gamocosm.minecraft_wrapper_username,
        password: @local_minecraft.minecraft_wrapper_password
      }
    }
  end

  def pid
    if @pid.nil?
      response = do_get(:pid)
      @pid = response.error? ? response : response['pid']
    end
    return @pid
  end

  def error?
    return pid.error?
  end

  def resume
    response = do_post(:start, { ram: "#{@local_minecraft.server.ram}M" })
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

  def update_wrapper
    response = do_post(:update_wrapper, {})
    if response.error?
      return response
    end
    return nil
  end

  def do_get(endpoint)
    begin
      response = self.class.get(full_url(endpoint), @options)
      response = parse_response(response, endpoint)
      return response
    rescue => e
      return "Exception in Minecraft node #{endpoint}: #{e}".error!
    end
  end

  def do_post(endpoint, data)
    begin
      options = @options.dup
      options[:body] = data.to_json
      response = parse_response(self.class.post(full_url(endpoint), options), endpoint, data)
      return response
    rescue => e
      return "Exception in Minecraft node #{endpoint}: #{e}".error!
    end
  end

  def full_url(endpoint)
    return "http://#{@ip_address}:#{@port}/#{endpoint}"
  end

  def parse_response(response, endpoint, data = nil)
    if response['status'] != 0
      return "Minecraft node #{endpoint} response status not OK, was #{response}".error!
    end
    return response
  end

  def invalidate
    @pid = nil
  end

end
