class ChangeDefaultSshPortInServers < ActiveRecord::Migration
  def up
    change_column :servers, :ssh_port, :integer, null: false, default: 4022
  end
  def down
    change_column :servers, :ssh_port, :integer, null: false, default: 22
  end
end
