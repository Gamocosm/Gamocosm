class AddRemoteSshSetupStageToMinecraftServers < ActiveRecord::Migration
  def change
    add_column :minecraft_servers, :remote_ssh_setup_stage, :integer, { default: 0, null: false }
  end
end
