class RemoveDigitalOceanMinecraftSnapshotIdFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :digital_ocean_minecraft_snapshot_id, :integer
  end
end
