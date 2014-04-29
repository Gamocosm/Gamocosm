class DigitalOcean::Connection

  attr_reader :request

  def initialize(client_id, api_key)
    @request = DigitalOcean::API.new(client_id: client_id, api_key: api_key, debug: false)
  end
end
