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

  def is_done?
    if has_error?
      raise "Digital ocean event #{@event_id} for user #{@user.id} had error #{@body}"
    end
    if @body['event'].nil?
      return false
    end
    return @body['event']['action_status'] == 'done'
  end
end
