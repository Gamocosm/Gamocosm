class DigitalOcean::Connection

  attr_reader :request

  def initialize(api_key)
    @request = Barge::Client.new(access_token: api_key)
  end
end
