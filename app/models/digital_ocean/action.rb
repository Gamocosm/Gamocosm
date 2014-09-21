class DigitalOcean::Action
  def initialize(droplet_remote_id, action_id, user)
    @action_id = action_id
    @droplet_remote_id = droplet_remote_id
    connection = user.digital_ocean
    if connection
      @response = connection.droplet.show_action(droplet_remote_id, action_id)
    else
      @response = 'Digital Ocean API token missing'.error!
    end
  end

  def data
    if error?
      return nil
    end
    return @response.action
  end

  def error?
    return @response.error? || !@response.success? || @response.action.status == 'errored'
  end

  def done?
    return @response.action.status == 'completed'
  end

  def show
    return @response
  end

end
