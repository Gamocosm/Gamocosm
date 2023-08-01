# https://github.com/heartcombo/devise/wiki/How-To:-Add-:confirmable-to-Users
class AddConfirmableToDevise < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    add_index :users, :confirmation_token
  end

  def down
    remove_index :users, :confirmation_token
    remove_columns :users, :confirmation_token, :confirmed_at, :confirmation_sent_at
    remove_column :users, :unconfirmed_email
  end
end
