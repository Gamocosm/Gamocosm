class MinecraftServer::Node
  include HTTParty
  default_timeout 2

  def initialize(local_minecraft_server, ip_address, port = '5000')
    @local_minecraft_server = local_minecraft_server
    @ip_address = ip_address
    @port = port
    @options = {
      headers: {
        'User-Agent' => 'Gamocosm',
        'Content-Type' => 'application/json'
      },
      basic_auth: {
        username: Gamocosm.minecraft_wrapper_username,
        password: @local_minecraft_server.minecraft_wrapper_password
      }
    }
  end

  def pid
    if @pid.nil?
      response = do_get(:pid)
      @pid = response.nil? ? false : response['pid']
    end
    return @pid == false ? nil : @pid
  end

  def resume
    response = do_post(:start, { ram: "#{@local_minecraft_server.ram}M" })
    invalidate
    return false if response.nil? # yes I know I can do return !response.nil? (or even return response)
    return true
  end

  def pause
    response = do_get(:stop)
    invalidate
    return false if response.nil?
    if response['retcode'] != 0
      # TODO: log
    end
    return true
  end

  def backup
    response = do_get(:backup)
    return false if response.nil?
    return true
  end

  def properties
    response = do_get(:minecraft_properties)
    return nil if response.nil?
    return response['properties']
  end

  def whitelist
    response = do_get(:whitelist)
    return nil if response.nil?
    return response['players']
  end

  def ops
    response = do_get(:ops)
    return nil if response.nil?
    return response['players']
  end

  def update_properties(properties)
    payload = {}
    properties.each_pair do |k, v|
      payload[k.to_s.gsub('_', '-')] = v.to_s
    end
    response = do_post(:minecraft_properties, { properties: payload })
    return nil if response.nil?
    return response['properties']
  end

  def update_whitelist(whitelist)
    response = do_post(:whitelist, { players: whitelist })
    return nil if response.nil?
    return response['players']
  end

  def update_ops(ops)
    response = do_post(:ops, { players: ops })
    return nil if response.nil?
    return response['players']
  end

  def update_wrapper
    response = do_get(:update_wrapper)
    return false if response.nil?
    return true
  end

  def download_world
  end

  def do_get(endpoint)
    begin
      response = self.class.get(full_url(endpoint), @options)
      response = parse_response(response)
      return response
    rescue
      # TODO: log
    end
    return nil
  end

  def do_post(endpoint, data)
    begin
      options = @options.dup
      options[:body] = data.to_json
      response = parse_response(self.class.post(full_url(endpoint), options))
      return response
    rescue
      # TODO: log
    end
    return nil
  end

  def full_url(endpoint)
    return "http://#{@ip_address}:#{@port}/#{endpoint}"
  end

  def parse_response(response)
    if response.nil?
      # TODO: log
      return nil
    end
    if response['status'] != 0
      # TODO: log
      return nil
    end
    return response
  end

  def invalidate
    @pid = nil
  end

end
