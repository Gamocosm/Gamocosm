class AddSshPortToServers < ActiveRecord::Migration
  def change
    add_column :servers, :ssh_port, :integer, null: false, default: 22
  end
end
