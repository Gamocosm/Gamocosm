class RemoveServerDomains < ActiveRecord::Migration
  def up
    add_column :minecrafts, :domain, :string
    Minecraft.all.each do |mc|
      sd = ServerDomain.find_by(server_id: mc.server.id)
      mc.update_columns({ domain: (sd.nil? ? ServerDomain.new.name : sd.name) })
    end
    change_column :minecrafts, :domain, :string, { null: false }
    add_index :minecrafts, :domain, { unique: true }
    drop_table :server_domains
  end

  def down
    create_table :server_domains do |t|
      t.integer :server_id, { null: false }
      t.string :name, { null: false }
    end
    Minecraft.all.each do |mc|
      sd = ServerDomain.new
      sd.name = mc.domain
      sd.server_id = mc.server.id
      sd.save!
    end
    add_index :server_domains, :name, { unique: true }
    add_foreign_key :server_domains, :servers, { on_delete: :cascade }
    remove_column :minecrafts, :domain
  end
end
