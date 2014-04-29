class AddSomeColumnsToSomeTables < ActiveRecord::Migration
  def change
    add_column :users, :digital_ocean_event_id, :integer
    add_column :minecraft_servers, :digital_ocean_droplet_size_id, :integer
  end
end
