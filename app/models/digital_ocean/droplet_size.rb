class DigitalOcean::DropletSize
  # cost_per_hour
  # cost_per_month
  # cpu
  # disk
  # id
  # memory
  # name
  # slug

  def initialize
    @all = Rails.cache.read(:digital_ocean_sizes)
    if @all.nil?
      begin
        connection = DigitalOcean::Connection.new(Gamocosm.digital_ocean_client_id, Gamocosm.digital_ocean_api_key).request
        # [#<Hashie::Rash cost_per_hour=0.00744 cost_per_month="5.0" cpu=1 descriptor="512MB" disk=20 id=66 memory=512 name="512MB" price_per_hour=0.00744 slug="512mb">]
        @all = connection.sizes.list.sizes
      rescue
      end
    end
    if !@all.blank?
      Rails.cache.write(:digital_ocean_sizes, @all)
    end
    @all ||= [
      Hashie::Rash.new(cost_per_hour: 0.00744, cost_per_month: "5.0", cpu: 1, disk: 20, id: 66, memory: 512, name: "512MB", slug: "512mb"),
      Hashie::Rash.new(cost_per_hour: 0.01488, cost_per_month: "10.0", cpu: 1, disk: 30, id: 63, memory: 1024, name: "1GB", slug: "1gb"),
      Hashie::Rash.new(cost_per_hour: 0.02976, cost_per_month: "20.0", cpu: 2, disk: 40, id: 62, memory: 2048, name: "2GB", slug: "2gb"),
      Hashie::Rash.new(cost_per_hour: 0.05952, cost_per_month: "40.0", cpu: 2, disk: 60, id: 64, memory: 4096, name: "4GB", slug: "4gb"),
      Hashie::Rash.new(cost_per_hour: 0.11905, cost_per_month: "80.0", cpu: 4, disk: 80, id: 65, memory: 8192, name: "8GB", slug: "8gb"),
      Hashie::Rash.new(cost_per_hour: 0.2381, cost_per_month: "160.0", cpu: 8, disk: 160, id: 61, memory: 16384, name: "16GB", slug: "16gb"),
      Hashie::Rash.new(cost_per_hour: 0.47619, cost_per_month: "320.0", cpu: 12, disk: 320, id: 60, memory: 32768, name: "32GB", slug: "32gb"),
      Hashie::Rash.new(cost_per_hour: 0.71429, cost_per_month: "480.0", cpu: 16, disk: 480, id: 70, memory: 49152, name: "48GB", slug: "48gb"),
      Hashie::Rash.new(cost_per_hour: 0.95238, cost_per_month: "640.0", cpu: 20, disk: 640, id: 69, memory: 65536, name: "64GB", slug: "64gb")]
    @all.map! do |x|
      x.descriptor = "#{x.name} at #{(x.cost_per_hour * 100).round(1)} cents/hour (up to $#{x.cost_per_month}/month)"
      x
    end
  end

  def all
    return @all
  end

  def default
    return @all.first
  end

  def find(digital_ocean_size_id)
    i = @all.index { |x| x.id == digital_ocean_size_id }
    if i
      return @all[i]
    end
    return nil
  end
end

=begin
[#<Hashie::Rash cost_per_hour=0.00744 cost_per_month="5.0" cpu=1 disk=20 id=66 memory=512 name="512MB" slug="512mb">, #<Hashie::Rash cost_per_hour=0.01488 cost_per_month="10.0" cpu=1 disk=30 id=63 memory=1024 name="1GB" slug="1gb">, #<Hashie::Rash cost_per_hour=0.02976 cost_per_month="20.0" cpu=2 disk=40 id=62 memory=2048 name="2GB" slug="2gb">, #<Hashie::Rash cost_per_hour=0.05952 cost_per_month="40.0" cpu=2 disk=60 id=64 memory=4096 name="4GB" slug="4gb">, #<Hashie::Rash cost_per_hour=0.11905 cost_per_month="80.0" cpu=4 disk=80 id=65 memory=8192 name="8GB" slug="8gb">, #<Hashie::Rash cost_per_hour=0.2381 cost_per_month="160.0" cpu=8 disk=160 id=61 memory=16384 name="16GB" slug="16gb">, #<Hashie::Rash cost_per_hour=0.47619 cost_per_month="320.0" cpu=12 disk=320 id=60 memory=32768 name="32GB" slug="32gb">, #<Hashie::Rash cost_per_hour=0.71429 cost_per_month="480.0" cpu=16 disk=480 id=70 memory=49152 name="48GB" slug="48gb">, #<Hashie::Rash cost_per_hour=0.95238 cost_per_month="640.0" cpu=20 disk=640 id=69 memory=65536 name="64GB" slug="64gb">]
=end
