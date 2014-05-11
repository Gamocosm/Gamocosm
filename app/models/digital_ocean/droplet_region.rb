class DigitalOcean::DropletRegion
  # name
  # slug

  def initialize
    @all = Rails.cache.read(:digital_ocean_regions)
    if @all.nil?
      begin
        connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_client_id, Gamocosm.digital_ocean_api_key).request
        response = connection.regions.list
        if response.status == 'OK'
          @all = response.regions
        end
      rescue
      end
    end
    if !@all.blank?
      Rails.cache.write(:digital_ocean_regions, @all)
    end
    @all ||= [
      Hashie::Rash.new(id: 3, name: "San Francisco 1", slug: "sfo1"),
      Hashie::Rash.new(id: 4, name: "New York 2", slug: "nyc2"),
      Hashie::Rash.new(id: 5, name: "Amsterdam 2", slug: "ams2"),
      Hashie::Rash.new(id: 6, name: "Singapore 1", slug: "sgp1")]
  end

  def all
    return @all
  end

  def default
    return @all.first
  end

  def find(digital_ocean_region_id)
    i = @all.index { |x| x.id == digital_ocean_region_id }
    if i
      return @all[i]
    end
    return nil
  end
end

=begin
#<Hashie::Rash regions=[#<Hashie::Rash id=3 name="San Francisco 1" slug="sfo1">, #<Hashie::Rash id=4 name="New York 2" slug="nyc2">, #<Hashie::Rash id=5 name="Amsterdam 2" slug="ams2">, #<Hashie::Rash id=6 name="Singapore 1" slug="sgp1">] status="OK">
=end

