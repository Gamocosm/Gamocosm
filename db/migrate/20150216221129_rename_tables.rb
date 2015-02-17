class RenameTables < ActiveRecord::Migration
  def change
    reversible do |change|
      change.up do
        remove_foreign_key :minecrafts, :users
        remove_foreign_key :servers, :minecrafts
        remove_foreign_key :server_logs, :minecrafts
        remove_foreign_key :minecrafts_users, :minecrafts
        remove_foreign_key :minecrafts_users, :users
      end
      change.down do
        add_foreign_key :minecrafts, :users, { on_delete: :cascade }
        add_foreign_key :servers, :minecrafts, { on_delete: :cascade }
        add_foreign_key :server_logs, :minecrafts, { on_delete: :cascade }
        add_foreign_key :minecrafts_users, :minecrafts, { on_delete: :cascade }
        add_foreign_key :minecrafts_users, :users, { on_delete: :cascade }
      end
    end

    rename_table :minecrafts, :servers2
    rename_index :servers2, :minecrafts_pkey, :servers2_pkey
    rename_table :servers, :minecrafts
    rename_table :servers2, :servers
    rename_index :servers, :servers2_pkey, :servers_pkey

    rename_table :minecrafts_users, :servers_users

    rename_column :minecrafts, :minecraft_id, :server_id
    rename_column :servers_users, :minecraft_id, :server_id
    rename_column :server_logs, :minecraft_id, :server_id

    add_foreign_key :servers, :users, { on_delete: :cascade }
    add_foreign_key :minecrafts, :servers, { on_delete: :cascade }
    add_foreign_key :server_logs, :servers, { on_delete: :cascade }
    add_foreign_key :servers_users, :servers, { on_delete: :cascade }
    add_foreign_key :servers_users, :users, { on_delete: :cascade }
  end
end
