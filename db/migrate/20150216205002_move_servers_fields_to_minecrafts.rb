class MoveServersFieldsToMinecrafts < ActiveRecord::Migration
  def up
    add_column :minecrafts, :pending_operation, :string
    add_column :minecrafts, :ssh_port, :integer
    add_column :minecrafts, :ssh_keys, :string
    add_column :minecrafts, :setup_stage, :integer
    add_column :minecrafts, :remote_id, :integer
    add_column :minecrafts, :remote_region_slug, :string
    add_column :minecrafts, :remote_size_slug, :string
    add_column :minecrafts, :remote_snapshot_id, :integer

    add_column :servers, :flavour, :string
    add_column :servers, :mcsw_password, :string
    add_column :servers, :autoshutdown_enabled, :boolean
    add_column :servers, :autoshutdown_last_check, :datetime
    add_column :servers, :autoshutdown_last_successful, :datetime

    Minecraft.all.each do |mc|
      s = mc.server
      mc.update_columns({
        pending_operation: s.pending_operation,
        ssh_port: s.ssh_port,
        ssh_keys: s.ssh_keys,
        setup_stage: s.remote_setup_stage,
        remote_id: s.remote_id,
        remote_region_slug: s.do_region_slug,
        remote_size_slug: s.do_size_slug,
        remote_snapshot_id: s.do_saved_snapshot_id,
      })
      s.update_columns({
        flavour: mc.flavour,
        mcsw_password: mc.minecraft_wrapper_password,
        autoshutdown_enabled: mc.autoshutdown_enabled,
        autoshutdown_last_check: mc.autoshutdown_last_check.nil? ? Time.now : mc.autoshutdown_last_check,
        autoshutdown_last_successful: mc.autoshutdown_last_successful.nil? ? Time.now : mc.autoshutdown_last_successful,
      })
    end

    change_column :minecrafts, :pending_operation, :string, { null: true, default: nil }
    change_column :minecrafts, :ssh_port, :integer, { null: false, default: 4022 }
    change_column :minecrafts, :ssh_keys, :string, { null: true, default: nil }
    change_column :minecrafts, :setup_stage, :integer, { null: false, default: 0 }
    change_column :minecrafts, :remote_id, :integer, { null: true, default: nil }
    change_column :minecrafts, :remote_region_slug, :string, { null: false }
    change_column :minecrafts, :remote_size_slug, :string, { null: false }
    change_column :minecrafts, :remote_snapshot_id, :integer, { null: true, default: nil }

    change_column :servers, :flavour, :string, { null: false }
    change_column :servers, :mcsw_password, :string, { null: false }
    change_column :servers, :autoshutdown_enabled, :boolean, { null: false, default: false }
    change_column :servers, :autoshutdown_last_check, :datetime, { null: false }
    change_column :servers, :autoshutdown_last_successful, :datetime, { null: false }

    remove_column :servers, :remote_id
    remove_column :servers, :do_region_slug
    remove_column :servers, :do_size_slug
    remove_column :servers, :do_saved_snapshot_id
    remove_column :servers, :remote_setup_stage
    remove_column :servers, :pending_operation
    remove_column :servers, :ssh_keys
    remove_column :servers, :ssh_port

    remove_column :minecrafts, :flavour
    remove_column :minecrafts, :minecraft_wrapper_password
    remove_column :minecrafts, :autoshutdown_enabled
    remove_column :minecrafts, :autoshutdown_last_check
    remove_column :minecrafts, :autoshutdown_last_successful
  end
  def down
    add_column :servers, :remote_id, :integer
    add_column :servers, :do_region_slug, :string
    add_column :servers, :do_size_slug, :string
    add_column :servers, :do_saved_snapshot_id, :integer
    add_column :servers, :remote_setup_stage, :integer
    add_column :servers, :pending_operation, :string
    add_column :servers, :ssh_keys, :string
    add_column :servers, :ssh_port, :integer

    add_column :flavour, :string
    add_column :minecraft_wrapper_password, :string
    add_column :autoshutdown_enabled, :boolean
    add_column :autoshutdown_last_check, :datetime
    add_column :autoshutdown_last_successful, :datetime

    Minecraft.all.each do |mc|
      s = mc.server
      s.update_columns({
        remote_id: mc.remote_id,
        do_region_slug: mc.remote_region_slug,
        do_size_slug: mc.remote_size_slug,
        do_saved_snapshot_id: mc.remote_snapshot_id,
        remote_setup_stage: mc.setup_stage,
        pending_operation: mc.pending_operation,
        ssh_keys: mc.ssh_keys,
        ssh_port: mc.ssh_port,
      })
      mc.update_columns({
        flavour: s.flavour,
        minecraft_wrapper_password: s.mcsw_password,
        autoshutdown_enabled: s.autoshutdown_enabled,
        autoshutdown_last_check: s.autoshutdown_last_check,
        autoshutdown_last_successful: s.autoshutdown_last_successful,
      })
    end

    remove_column :minecrafts, :pending_operation, :string
    remove_column :minecrafts, :ssh_port, :integer
    remove_column :minecrafts, :ssh_keys, :string
    remove_column :minecrafts, :setup_stage, :integer
    remove_column :minecrafts, :remote_id, :integer
    remove_column :minecrafts, :remote_region_slug, :string
    remove_column :minecrafts, :remote_size_slug, :string
    remove_column :minecrafts, :remote_snapshot_id, :integer

    remove_column :servers, :flavour, :string
    remove_column :servers, :mcsw_password, :string
    remove_column :servers, :autoshutdown_enabled, :boolean
    remove_column :servers, :autoshutdown_last_check, :datetime
    remove_column :servers, :autoshutdown_last_successful, :datetime
  end
end
