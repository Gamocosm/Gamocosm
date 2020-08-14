class AddPreserveSnapshotToServers < ActiveRecord::Migration[6.0]
  def change
    add_column :servers, :preserve_snapshot, :boolean, { null: false, default: false }
  end
end
