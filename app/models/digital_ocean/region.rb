class DigitalOcean::Region
  # name
  # slug

  def initialize
    @all = Rails.cache.read(:digital_ocean_regions)
    if @all.nil?
      begin
        connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_api_key).request
        response = connection.region.all
        if response.success?
          @all = response.regions.select { |x| x.available }.map { |x| { name: x.name, slug: x.slug } }
        else
          Rails.logger.error "Unable to get Digital Ocean regions in DO::Region; #{response}"
        end
      rescue
      end
    end
    if @all.nil?
      @all = [
        { name: "Amsterdam 3", slug: "ams3" }
        { name: "New York 3", slug: "nyc3" },
        { name: "Amsterdam 2", slug: "ams2" },
        { name: "New York 2", slug: "nyc2" },
        { name: "London 1", slug: "lon1" },
        { name: "San Francisco 1", slug: "sfo1" },
        { name: "Singapore 1", slug: "sgp1" },
      ]
    else
      Rails.cache.write(:digital_ocean_regions, @all)
    end
  end

  def all
    return @all.sort do |a, b|
      a_tier = a[:slug][-1]
      b_tier = b[:slug][-1]
      a_tier == b_tier ? a[:name] <=> b[:name] : b_tier <=> a_tier
    end
  end

  def find(digital_ocean_region_slug)
    i = @all.index { |x| x[:slug] == digital_ocean_region_slug }
    if i
      return @all[i]
    end
    return nil
  end
end
