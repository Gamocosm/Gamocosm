class AddMoreConstraints < ActiveRecord::Migration
  def change
    change_column :minecraft_servers, :name, :string, null: false
    change_column :minecraft_servers, :remote_setup_stage, :integer, null: false
    change_column :minecraft_servers, :minecraft_wrapper_password, :string, null: false
    change_column :minecraft_servers, :digital_ocean_region_slug, :string, null: false
    change_column :minecraft_servers, :digital_ocean_size_slug, :string, null: false

    remove_column :users, :digital_ocean_event_id, :integer
  end
end
