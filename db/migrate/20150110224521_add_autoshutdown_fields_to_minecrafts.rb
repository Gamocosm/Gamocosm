class AddAutoshutdownFieldsToMinecrafts < ActiveRecord::Migration
  def change
    add_column :minecrafts, :autoshutdown_enabled, :boolean, { null: false, default: false }
    add_column :minecrafts, :autoshutdown_last_check, :datetime, { null: true, default: nil }
    add_column :minecrafts, :autoshutdown_last_successful, :datetime, { null: true, default: nil }
  end
end
