class RenameTables < ActiveRecord::Migration
  def change
    rename_table :minecrafts, :servers2
    rename_table :servers, :minecrafts
    rename_table :servers2, :servers
    rename_table :minecrafts_users, :servers_users

    rename_column :minecrafts, :minecraft_id, :server_id
    rename_column :servers_users, :minecraft_id, :server_id
    rename_column :server_logs, :minecraft_id, :server_id
  end
=begin
  def up
    return
    remove_foreign_key :minecrafts, :users
    remove_foreign_key :minecrafts_users, :minecrafts
    remove_foreign_key :minecrafts_users, :sers
    remove_foreign_key :server_logs, :minecrafts
    remove_foreign_key :servers, :minecrafts
  end
  def down
    return
    add_foreign_key :minecrafts, :users, { on_delete: :cascade }
    add_foreign_key :minecrafts_users, :minecrafts, { on_delete: :cascade }
    add_foreign_key :minecrafts_users, :users, { on_delete: :cascade }
    add_foreign_key :server_logs, :minecrafts, { on_delete: :cascade }
    add_foreign_key :servers, :minecrafts, { on_delete: :cascade }
  end
=end
end
