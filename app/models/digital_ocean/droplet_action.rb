class DigitalOcean::DropletAction
  def initialize(droplet_remote_id, action_id, user)
    @action_id = action_id
    @droplet_remote_id = droplet_remote_id
    # Actions are sorted by descending numerical id; most recent action at [0]
    # #<Barge::Response action=#<Hashie::Mash completed_at="2014-08-25T04:52:52Z" id=31352159 region="nyc2" resource_id=2444491 resource_type="droplet" started_at="2014-08-25T04:51:40Z" status="completed" type="snapshot">>
    connection = user.digital_ocean
    if connection
      @response = connection.droplet.show_action(droplet_remote_id, action_id)
    end
  end

  def data
    if has_error?
      return nil
    end
    return @response.action
  end

  def has_error?
    return !@response.success? || @response.action.status == 'errored'
  end

  def is_done?
    return @response.action.status == 'completed'
  end

  def show
    return @response
  end

  def resource_id
    return @response.action.resource_id
  end
end
