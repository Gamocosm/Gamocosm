class CreateServerLogs < ActiveRecord::Migration
  def change
    create_table :server_logs do |t|
      t.uuid :minecraft_id, null: false
      t.string :message, null: false
      t.string :debuginfo, null: false
      t.timestamps
    end
    add_index :server_logs, :minecraft_id
    add_foreign_key :server_logs, :minecrafts, dependent: :delete
    change_column :minecrafts, :user_id, :integer, null: false
    change_column :servers, :minecraft_id, :uuid, null: false
  end
end
