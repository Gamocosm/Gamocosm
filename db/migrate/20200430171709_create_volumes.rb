class CreateVolumes < ActiveRecord::Migration[6.0]
  def change
    create_table :volumes do |t|
      t.string :remote_id
      t.integer :remote_size_gb
      t.string :remote_region_slug
      t.string :remote_snapshot_id

      t.timestamps
    end
  end
end
