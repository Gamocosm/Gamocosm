class AddSshKeysToServers < ActiveRecord::Migration
  def change
    add_column :servers, :ssh_keys, :string
  end
end
