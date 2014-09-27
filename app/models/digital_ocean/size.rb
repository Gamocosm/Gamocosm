class DigitalOcean::Size
  # cost_per_hour
  # cost_per_month
  # cpu
  # disk
  # memory
  # name
  # slug

  def initialize
    @all = Rails.cache.read(:digital_ocean_sizes)
    if @all.nil?
      begin
        connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_api_key).request
        response = connection.size.all
        if response.success?
          @all = response.sizes.map { |x| {
            cost_per_hour: x.price_hourly,
            cost_per_month: x.price_monthly,
            cpu: x.vcpus,
            disk: x.disk,
            memory: x.memory,
            name: x.slug.upcase,
            slug: x.slug
          } }
        else
          Rails.logger.error "Unable to get Digital Ocean sizes in DO::Size; #{response}"
        end
      rescue
      end
    end
    if @all.nil?
      @all = [
        { cost_per_hour: 0.00744, cost_per_month: 5.0, cpu: 1, disk: 20, memory: 512, name: "512MB", slug: "512mb" },
        { cost_per_hour: 0.01488, cost_per_month: 10.0, cpu: 1, disk: 30, memory: 1024, name: "1GB", slug: "1gb" },
        { cost_per_hour: 0.02976, cost_per_month: 20.0, cpu: 2, disk: 40, memory: 2048, name: "2GB", slug: "2gb" },
        { cost_per_hour: 0.05952, cost_per_month: 40.0, cpu: 2, disk: 60, memory: 4096, name: "4GB", slug: "4gb" },
        { cost_per_hour: 0.11905, cost_per_month: 80.0, cpu: 4, disk: 80, memory: 8192, name: "8GB", slug: "8gb" },
        { cost_per_hour: 0.2381, cost_per_month: 160.0, cpu: 8, disk: 160, memory: 16384, name: "16GB", slug: "16gb" },
        { cost_per_hour: 0.47619, cost_per_month: 320.0, cpu: 12, disk: 320, memory: 32768, name: "32GB", slug: "32gb" },
        { cost_per_hour: 0.71429, cost_per_month: 480.0, cpu: 16, disk: 480, memory: 49152, name: "48GB", slug: "48gb" },
        { cost_per_hour: 0.95238, cost_per_month: 640.0, cpu: 20, disk: 640, memory: 65536, name: "64GB", slug: "64gb" }
      ]
    else
      Rails.cache.write(:digital_ocean_sizes, @all)
    end
    @all.map! do |x|
      x[:price] = "#{(x[:cost_per_hour] * 100).round(1)} cents/hour"
      x[:descriptor] = "#{x[:name]} at #{x[:price]} (up to $#{x[:cost_per_month]}/month)"
      x[:players] = (x[:memory] / 100).round.to_s
      x
    end
  end

  def all
    return @all
  end

  def default
    return @all.first
  end

  def find(digital_ocean_size_slug)
    i = @all.index { |x| x[:slug] == digital_ocean_size_slug }
    if i
      return @all[i]
    end
    return nil
  end
end
