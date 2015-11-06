class CreateScheduledTasks < ActiveRecord::Migration
  def change
    create_table :scheduled_tasks do |t|
      t.uuid :server_id, { null: false }
      t.integer :partition, { null: false }
      t.string :action, { null: false }
    end
    add_foreign_key :scheduled_tasks, :servers, { on_delete: :cascade }
    add_index :scheduled_tasks, :partition
  end
end
