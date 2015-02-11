class DigitalOcean::Size
  # price_hourly
  # price_monthly
  # cpu
  # disk
  # memory
  # name
  # slug

  DEFAULT_SIZES = [
    { price_hourly: 0.00744, price_monthly: 5.0, cpu: 1, disk: 20, memory: 512, name: "512MB", slug: "512mb" },
    { price_hourly: 0.01488, price_monthly: 10.0, cpu: 1, disk: 30, memory: 1024, name: "1GB", slug: "1gb" },
    { price_hourly: 0.02976, price_monthly: 20.0, cpu: 2, disk: 40, memory: 2048, name: "2GB", slug: "2gb" },
    { price_hourly: 0.05952, price_monthly: 40.0, cpu: 2, disk: 60, memory: 4096, name: "4GB", slug: "4gb" },
    { price_hourly: 0.11905, price_monthly: 80.0, cpu: 4, disk: 80, memory: 8192, name: "8GB", slug: "8gb" },
    { price_hourly: 0.2381, price_monthly: 160.0, cpu: 8, disk: 160, memory: 16384, name: "16GB", slug: "16gb" },
    { price_hourly: 0.47619, price_monthly: 320.0, cpu: 12, disk: 320, memory: 32768, name: "32GB", slug: "32gb" },
    { price_hourly: 0.71429, price_monthly: 480.0, cpu: 16, disk: 480, memory: 49152, name: "48GB", slug: "48gb" },
    { price_hourly: 0.95238, price_monthly: 640.0, cpu: 20, disk: 640, memory: 65536, name: "64GB", slug: "64gb" }
  ]

  def initialize
    @all = Rails.cache.read(:digital_ocean_sizes)
    if @all.nil?
      begin
        connection = DigitalOcean::Connection.new(Gamocosm::DIGITAL_OCEAN_API_KEY).request
        response = connection.size.all
        if response.success?
          @all = response.sizes.map { |x| {
            price_hourly: x.price_hourly,
            price_monthly: x.price_monthly,
            cpu: x.vcpus,
            disk: x.disk,
            memory: x.memory,
            name: x.slug.upcase,
            slug: x.slug
          } }
          Rails.cache.write(:digital_ocean_sizes, @all, expires_in: 24.hours)
        else
          Rails.logger.error "Unable to get Digital Ocean sizes in DO::Size; #{response}"
        end
      rescue
      end
    end
    if @all.nil?
      @all = DEFAULT_SIZES
    end
    @all.map! do |x|
      x[:price] = "#{(x[:price_hourly] * 100).round(1)} cents/hour"
      x[:descriptor] = "#{x[:name]} at #{x[:price]} (up to $#{x[:price_monthly]}/month)"
      x[:players] = (x[:memory] / 100).round.to_s
      x
    end
  end

  def all
    return @all
  end

  def find(digital_ocean_size_slug)
    i = @all.index { |x| x[:slug] == digital_ocean_size_slug }
    if i
      return @all[i]
    end
    return nil
  end
end
