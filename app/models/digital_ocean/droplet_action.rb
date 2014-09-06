class DigitalOcean::DropletAction
  def initialize(droplet_remote_id, action_id, user)
    connection = user.digital_ocean
    if connection.nil?
      return nil
    end
    @action_id = action_id
    @droplet_remote_id = droplet_remote_id
    # #<Barge::Response action=#<Hashie::Mash completed_at="2014-08-25T04:52:52Z" id=31352159 region="nyc2" resource_id=2444491 resource_type="droplet" started_at="2014-08-25T04:51:40Z" status="completed" type="snapshot">>
    @response = connection.droplet.show_action(droplet_remote_id, action_id)
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
    if has_error?
      raise "DO::DropletAction#is_done?: response #{@response}, remote droplet #{@droplet_remote_id}, event #{@action_id}"
    end
    return @response.action.status == 'completed'
  end

  def show
    return "#{@response}"
  end
end
