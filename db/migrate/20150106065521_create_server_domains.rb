class CreateServerDomains < ActiveRecord::Migration
  def change
    create_table :server_domains do |t|
      t.references :server, index: true, null: false
      t.string :name, default: nil
    end
    add_index :server_domains, [:name], { unique: true }
    add_foreign_key :server_domains, :servers, { column: :server_id, primary_key: :id, dependent: :delete }
  end
end
