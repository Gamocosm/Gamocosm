class RemoveOldFields < ActiveRecord::Migration
  def change
    remove_column :minecraft_servers, :should_destroy, :boolean
    remove_column :droplets, :ip_address, :inet
    remove_column :droplets, :remote_status, :string
    remove_column :droplets, :last_synced, :datetime
    remove_column :droplets, :remote_region_slug, :string
    remove_column :droplets, :remote_size_slug, :string
    remove_column :minecraft_servers, :digital_ocean_pending_event_id, :integer
  end
end
