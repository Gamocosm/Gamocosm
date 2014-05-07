class ChangeMinecraftServerIdToUuidDroplets < ActiveRecord::Migration
  def change
    remove_column :droplets, :minecraft_server_id
    add_column :droplets, :minecraft_server_id, :uuid
  end
end
