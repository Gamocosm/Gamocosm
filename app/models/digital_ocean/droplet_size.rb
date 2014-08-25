class DigitalOcean::DropletSize
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
        # [#<Hashie::Rash cost_per_hour=0.00744 cost_per_month="5.0" cpu=1 descriptor="512MB" disk=20 id=66 memory=512 name="512MB" price_per_hour=0.00744 slug="512mb">]
        # [#<Hashie::Mash disk=20 memory=512 price_hourly=0.00744 price_monthly=5.0 regions=["nyc1", "sgp1", "ams1", "ams2", "sfo1", "nyc2", "lon1", "nyc3"] slug="512mb" transfer=1 vcpus=1>]
        @all = connection.sizes.list.sizes.map { |x| {
          cost_per_hour: x.cost_per_hour,
          cost_per_month: x.cost_per_month,
          cpu: x.cpu,
          disk: x.disk,
          memory: x.memory,
          name: x.slug.upcase,
          slug: x.slug
        } }
      rescue
      end
    end
    if !@all.blank?
      Rails.cache.write(:digital_ocean_sizes, @all)
    end
    @all ||= [
      { cost_per_hour: 0.00744, cost_per_month: "5.0", cpu: 1, disk: 20, id: 66, memory: 512, name: "512MB", slug: "512mb" },
      { cost_per_hour: 0.01488, cost_per_month: "10.0", cpu: 1, disk: 30, id: 63, memory: 1024, name: "1GB", slug: "1gb" },
      { cost_per_hour: 0.02976, cost_per_month: "20.0", cpu: 2, disk: 40, id: 62, memory: 2048, name: "2GB", slug: "2gb" },
      { cost_per_hour: 0.05952, cost_per_month: "40.0", cpu: 2, disk: 60, id: 64, memory: 4096, name: "4GB", slug: "4gb" },
      { cost_per_hour: 0.11905, cost_per_month: "80.0", cpu: 4, disk: 80, id: 65, memory: 8192, name: "8GB", slug: "8gb" },
      { cost_per_hour: 0.2381, cost_per_month: "160.0", cpu: 8, disk: 160, id: 61, memory: 16384, name: "16GB", slug: "16gb" },
      { cost_per_hour: 0.47619, cost_per_month: "320.0", cpu: 12, disk: 320, id: 60, memory: 32768, name: "32GB", slug: "32gb" },
      { cost_per_hour: 0.71429, cost_per_month: "480.0", cpu: 16, disk: 480, id: 70, memory: 49152, name: "48GB", slug: "48gb" },
      { cost_per_hour: 0.95238, cost_per_month: "640.0", cpu: 20, disk: 640, id: 69, memory: 65536, name: "64GB", slug: "64gb" }]
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
    i = @all.index { |x| x[:id] == digital_ocean_size_slug }
    if i
      return @all[i]
    end
    return nil
  end
end

=begin
[#<Hashie::Rash cost_per_hour=0.00744 cost_per_month="5.0" cpu=1 disk=20 id=66 memory=512 name="512MB" slug="512mb">, #<Hashie::Rash cost_per_hour=0.01488 cost_per_month="10.0" cpu=1 disk=30 id=63 memory=1024 name="1GB" slug="1gb">, #<Hashie::Rash cost_per_hour=0.02976 cost_per_month="20.0" cpu=2 disk=40 id=62 memory=2048 name="2GB" slug="2gb">, #<Hashie::Rash cost_per_hour=0.05952 cost_per_month="40.0" cpu=2 disk=60 id=64 memory=4096 name="4GB" slug="4gb">, #<Hashie::Rash cost_per_hour=0.11905 cost_per_month="80.0" cpu=4 disk=80 id=65 memory=8192 name="8GB" slug="8gb">, #<Hashie::Rash cost_per_hour=0.2381 cost_per_month="160.0" cpu=8 disk=160 id=61 memory=16384 name="16GB" slug="16gb">, #<Hashie::Rash cost_per_hour=0.47619 cost_per_month="320.0" cpu=12 disk=320 id=60 memory=32768 name="32GB" slug="32gb">, #<Hashie::Rash cost_per_hour=0.71429 cost_per_month="480.0" cpu=16 disk=480 id=70 memory=49152 name="48GB" slug="48gb">, #<Hashie::Rash cost_per_hour=0.95238 cost_per_month="640.0" cpu=20 disk=640 id=69 memory=65536 name="64GB" slug="64gb">]
=end
=begin
#<Barge::Response meta=#<Hashie::Mash total=9> sizes=[#<Hashie::Mash disk=20 memory=512 price_hourly=0.00744 price_monthly=5.0 regions=["nyc1", "sgp1", "ams1", "ams2", "sfo1", "nyc2", "lon1", "nyc3"] slug="512mb" transfer=1 vcpus=1>, #<Hashie::Mash disk=30 memory=1024 price_hourly=0.01488 price_monthly=10.0 regions=["nyc1", "nyc2", "sgp1", "ams1", "sfo1", "ams2", "lon1", "nyc3"] slug="1gb" transfer=2 vcpus=1>, #<Hashie::Mash disk=40 memory=2048 price_hourly=0.02976 price_monthly=20.0 regions=["nyc1", "nyc2", "sfo1", "ams1", "sgp1", "ams2", "lon1", "nyc3"] slug="2gb" transfer=3 vcpus=2>, #<Hashie::Mash disk=60 memory=4096 price_hourly=0.05952 price_monthly=40.0 regions=["nyc2", "sfo1", "ams1", "sgp1", "ams2", "nyc1", "lon1", "nyc3"] slug="4gb" transfer=4 vcpus=2>, #<Hashie::Mash disk=80 memory=8192 price_hourly=0.11905 price_monthly=80.0 regions=["nyc2", "sfo1", "sgp1", "ams1", "ams2", "nyc1", "lon1", "nyc3"] slug="8gb" transfer=5 vcpus=4>, #<Hashie::Mash disk=160 memory=16384 price_hourly=0.2381 price_monthly=160.0 regions=["sgp1", "nyc1", "sfo1", "lon1", "ams2", "nyc3", "nyc2"] slug="16gb" transfer=6 vcpus=8>, #<Hashie::Mash disk=320 memory=32768 price_hourly=0.47619 price_monthly=320.0 regions=["nyc2", "sgp1", "ams2", "nyc1", "sfo1", "lon1", "nyc3"] slug="32gb" transfer=7 vcpus=12>, #<Hashie::Mash disk=480 memory=49152 price_hourly=0.71429 price_monthly=480.0 regions=["sgp1", "ams2", "sfo1", "nyc1", "lon1", "nyc3", "nyc2"] slug="48gb" transfer=8 vcpus=16>, #<Hashie::Mash disk=640 memory=65536 price_hourly=0.95238 price_monthly=640.0 regions=["sgp1", "ams2", "nyc1", "nyc2", "sfo1", "lon1", "nyc3"] slug="64gb" transfer=9 vcpus=20>]>
=end
