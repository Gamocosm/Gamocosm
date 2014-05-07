class AddShouldDestroyToMinecraftServers < ActiveRecord::Migration
  def change
    add_column :minecraft_servers, :should_destroy, :boolean, null: false, default: false
  end
end
