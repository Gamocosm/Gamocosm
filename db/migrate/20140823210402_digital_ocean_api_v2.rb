class DigitalOceanApiV2 < ActiveRecord::Migration
  def change
    remove_column :users, :digital_ocean_client_id, :string
    remove_column :droplets, :remote_region_id, :integer
    add_column :droplets, :remote_region_slug, :string
    remove_column :droplets, :remote_size_id, :integer
    add_column :droplets, :remote_size_slug, :string
    remove_column :minecraft_servers, :digital_ocean_droplet_region_id, :integer
    add_column :minecraft_servers, :digital_ocean_region_slug, :string
    remove_column :minecraft_servers, :digital_ocean_droplet_size_id, :integer
    add_column :minecraft_servers, :digital_ocean_size_slug, :string
  end
end
