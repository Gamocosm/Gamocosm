class CreateMinecraftServers < ActiveRecord::Migration
  def change
    enable_extension 'uuid-ossp'
    create_table :minecraft_servers, id: :uuid do |t|
      t.references :user, index: true
      t.string :name
      t.integer :saved_snapshot_id
      t.string :pending_operation

      t.timestamps
    end
  end
end
