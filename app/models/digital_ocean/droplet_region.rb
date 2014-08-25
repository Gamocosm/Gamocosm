class DigitalOcean::DropletRegion
  # name
  # slug

  def initialize
    @all = Rails.cache.read(:digital_ocean_regions)
    if @all.nil?
      begin
        connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_api_key).request
        response = connection.region.all
        if response.success?
          @all = response.regions.map { |x| { name: x.name, slug: x.slug } }
        end
      rescue
      end
    end
    if !@all.blank?
      Rails.cache.write(:digital_ocean_regions, @all)
    end
    @all ||= [
      { name: "San Francisco 1", slug: "sfo1" },
      { name: "New York 2", slug: "nyc2" },
      { name: "Amsterdam 2", slug: "ams2" },
      { name: "Singapore 1", slug: "sgp1" }]
  end

  def all
    return @all
  end

  def default
    return @all.first
  end

  def find(digital_ocean_region_slug)
    i = @all.index { |x| x[:slug] == digital_ocean_region_slug }
    if i
      return @all[i]
    end
    return nil
  end
end

=begin
#<Hashie::Rash regions=[#<Hashie::Rash id=3 name="San Francisco 1" slug="sfo1">, #<Hashie::Rash id=4 name="New York 2" slug="nyc2">, #<Hashie::Rash id=5 name="Amsterdam 2" slug="ams2">, #<Hashie::Rash id=6 name="Singapore 1" slug="sgp1">] status="OK">
=end
=begin
#<Barge::Response meta=#<Hashie::Mash total=8> regions=[#<Hashie::Mash available=false features=["virtio", "backups"] name="New York 1" sizes=[] slug="nyc1">, #<Hashie::Mash available=false features=["virtio", "backups"] name="Amsterdam 1" sizes=[] slug="ams1">, #<Hashie::Mash available=true features=["virtio", "backups"] name="San Francisco 1" sizes=["2gb", "4gb", "8gb", "1gb", "16gb", "32gb", "48gb", "512mb", "64gb"] slug="sfo1">, #<Hashie::Mash available=true features=["virtio", "private_networking", "backups"] name="New York 2" sizes=["1gb", "2gb", "4gb", "8gb", "32gb", "64gb", "512mb", "16gb", "48gb"] slug="nyc2">, #<Hashie::Mash available=true features=["virtio", "private_networking", "backups"] name="Amsterdam 2" sizes=["512mb", "1gb", "2gb", "4gb", "8gb", "32gb", "48gb", "64gb", "16gb"] slug="ams2">, #<Hashie::Mash available=true features=["virtio", "private_networking", "backups", "ipv6"] name="Singapore 1" sizes=["1gb", "512mb", "2gb", "4gb", "8gb", "16gb", "32gb", "48gb", "64gb"] slug="sgp1">, #<Hashie::Mash available=true features=["virtio", "private_networking", "backups", "ipv6"] name="London 1" sizes=["512mb", "1gb", "2gb", "4gb", "8gb", "16gb", "32gb", "48gb", "64gb"] slug="lon1">, #<Hashie::Mash available=true features=["virtio", "private_networking", "backups", "ipv6"] name="New York 3" sizes=["512mb", "1gb", "2gb", "4gb", "8gb", "16gb", "32gb", "48gb", "64gb"] slug="nyc3">]>
=end
