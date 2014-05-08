class AddRemoteSetupStageToMinecraftServers < ActiveRecord::Migration
  def change
    add_column :minecraft_servers, :remote_setup_stage, :integer, default: 0
  end
end
