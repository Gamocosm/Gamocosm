class AddDigitalOceanDropletRegionIdToMinecraftServers < ActiveRecord::Migration
  def change
    add_column :minecraft_servers, :digital_ocean_droplet_region_id, :integer
  end
end
