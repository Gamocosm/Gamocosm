class AddDigitalOceanPendingEventIdToMinecraftServers < ActiveRecord::Migration
  def change
    add_column :minecraft_servers, :digital_ocean_pending_event_id, :integer
  end
end
