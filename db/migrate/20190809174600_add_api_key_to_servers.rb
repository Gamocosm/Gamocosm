class AddApiKeyToServers < ActiveRecord::Migration[5.2]
  def change
    add_column :servers, :api_key, :string

    reversible do |dir|
      dir.up do
        Server.all.each do |s|
          s.api_key = SecureRandom.hex(16)
          s.save
        end
        change_column :servers, :api_key, :string, { null: false }
      end
      dir.down do
      end
    end
  end
end
