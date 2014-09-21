class RenameStuff < ActiveRecord::Migration
  def change
    rename_table :minecraft_servers, :minecrafts
    rename_table :droplets, :servers
    rename_column :servers, :minecraft_server_id, :minecraft_id
    rename_table :minecraft_servers_users, :minecrafts_users
    rename_column :minecrafts_users, :minecraft_server_id, :minecraft_id

    remove_foreign_key :servers, name: 'droplets_minecraft_server_id_fk'
    remove_foreign_key :minecrafts, name: 'minecraft_servers_user_id_fk'
    remove_foreign_key :minecrafts_users, name: 'minecraft_servers_users_minecraft_server_id_fk'
    remove_foreign_key :minecrafts_users, name: 'minecraft_servers_users_user_id_fk'
    add_foreign_key :servers, :minecrafts, { column: :minecraft_id, primary_key: :id, dependent: :delete }
    add_foreign_key :minecrafts, :users, { column: :user_id, primary_key: :id, dependent: :delete }
    add_foreign_key :minecrafts_users, :users, { column: :user_id, primary_key: :id, dependent: :delete }
    add_foreign_key :minecrafts_users, :minecrafts, { column: :minecraft_id, primary_key: :id, dependent: :delete }

    add_index :minecrafts_users, [:minecraft_id, :user_id], { unique: true }

    add_column :servers, :do_region_slug, :string, { null: false }
    add_column :servers, :do_size_slug, :string, { null: false }
    add_column :servers, :do_saved_snapshot_id, :integer
    add_column :servers, :remote_setup_stage, :integer, { null: false, default: 0 }
    add_column :servers, :pending_operation, :string
    remove_column :minecrafts, :digital_ocean_region_slug
    remove_column :minecrafts, :digital_ocean_size_slug
    remove_column :minecrafts, :saved_snapshot_id
    remove_column :minecrafts, :remote_setup_stage
    remove_column :minecrafts, :remote_ssh_setup_stage
    remove_column :minecrafts, :pending_operation
  end
end
