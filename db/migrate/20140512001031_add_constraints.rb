class AddConstraints < ActiveRecord::Migration
  def change
    add_index :droplets, [:minecraft_server_id], { unique: true }
    add_index :minecraft_servers_users, [:minecraft_server_id, :user_id], { unique: true, name: 'index_mc_servers_users_on_mc_server_id_and_user_id' }
    add_index :minecraft_servers_users, [:minecraft_server_id]

    add_foreign_key :droplets, :minecraft_servers, { column: :minecraft_server_id, primary_key: :id, dependent: :delete }
    add_foreign_key :minecraft_servers, :users, { column: :user_id, primary_key: :id, dependent: :delete }
    add_foreign_key :minecraft_servers_users, :users, { column: :user_id, primary_key: :id, dependent: :delete }
    add_foreign_key :minecraft_servers_users, :minecraft_servers, { column: :minecraft_server_id, primary_key: :id, dependent: :delete }
  end
end
