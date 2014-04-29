class CreateMinecraftServersUsers < ActiveRecord::Migration
  def change
    create_table :minecraft_servers_users do |t|
      t.uuid :minecraft_server_id, index: true
      t.references :user, index: true
    end
  end
end
