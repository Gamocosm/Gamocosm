class DigitalOcean::DropletSize

  def initialize
    @connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_client_id, Gamocosm.digital_ocean_api_key).request
  end

  def all
    return @connection.sizes.list.sizes.map do |x|
      x.price_per_hour = x.cost_per_hour
      x.descriptor = x.name
      x
    end
  end

  def default
    return all.first
  end

  def available
    return all
  end
end
