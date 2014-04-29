class AddDigitalOceanColumnsToUser < ActiveRecord::Migration
  def change
    add_column :users, :digital_ocean_client_id, :string
    add_column :users, :digital_ocean_api_key, :string
    add_column :users, :digital_ocean_minecraft_snapshot_id, :integer
  end
end
