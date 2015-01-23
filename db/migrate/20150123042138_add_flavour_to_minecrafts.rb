class AddFlavourToMinecrafts < ActiveRecord::Migration
  def change
    add_column :minecrafts, :flavour, :string, { null: false, default: 'vanilla/null' }
  end
end
