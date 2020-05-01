class CreateVolumes < ActiveRecord::Migration[6.0]
  def change
    enable_extension 'pgcrypto'
    create_table :volumes, id: :uuid do |t|
      t.integer :user_id, { null: false }
      t.string :name, { null: false }
      t.string :remote_id, { null: true }
      t.string :remote_snapshot_id, { null: true }
      t.integer :remote_size_gb, { null: false }
      t.string :remote_region_slug, { null: false }

      t.timestamps
    end
    add_index :volumes, :user_id
    add_index :volumes, :name, { unique: true }
    add_foreign_key :volumes, :users, { on_delete: :cascade }
  end
end
