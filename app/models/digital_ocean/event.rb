class DigitalOcean::Event
  include HTTParty

  def initialize(event_id, user)
    @event_id = event_id
    @user = user
    @response = self.class.get("https://api.digitalocean.com/events/#{@event_id}/?client_id=#{user.digital_ocean_client_id}&api_key=#{user.digital_ocean_api_key}")
    @body = JSON.parse(@response.body)
  end

  def show
    return @body
  end

  def has_error?
    return !(@body['status'] == 'OK' && @body['error_message'].nil?)
  end

  def data
    return @body['event']
  end

  def is_done?
    if has_error?
      raise "DO::Event#is_done?: response #{@body}, event #{@event_id}"
    end
    if data.nil?
      return false
    end
    return data['action_status'] == 'done'
  end

  def percentage
    if has_error?
      return nil
    end
    return data['percentage']
  end
end
