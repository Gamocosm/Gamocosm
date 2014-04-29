class CreateDroplets < ActiveRecord::Migration
  def change
    create_table :droplets do |t|
      t.references :minecraft_server, index: true
      t.integer :remote_id
      t.integer :remote_size_id
      t.integer :remote_region_id
      t.inet :ip_address
      t.string :remote_status
      t.datetime :last_synced

      t.timestamps
    end
  end
end
