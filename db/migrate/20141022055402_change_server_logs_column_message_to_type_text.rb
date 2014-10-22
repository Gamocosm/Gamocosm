class ChangeServerLogsColumnMessageToTypeText < ActiveRecord::Migration
  def up
    change_column :server_logs, :message, :text
  end
  def down
    change_column :server_logs, :message, :string
  end
end
