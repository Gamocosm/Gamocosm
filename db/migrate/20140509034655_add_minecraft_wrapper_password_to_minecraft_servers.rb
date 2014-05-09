class AddMinecraftWrapperPasswordToMinecraftServers < ActiveRecord::Migration
  def change
    add_column :minecraft_servers, :minecraft_wrapper_password, :string
  end
end
