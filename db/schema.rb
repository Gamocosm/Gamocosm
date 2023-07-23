# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_08_13_163157) do

  # These are extensions that must be enabled in order to support this database
  enable_extension 'pgcrypto'
  enable_extension 'plpgsql'
  enable_extension 'uuid-ossp'

  create_table 'minecrafts', force: :cascade do |t|
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.uuid 'server_id', null: false
    t.string 'flavour', null: false
    t.string 'mcsw_password', null: false
    t.boolean 'autoshutdown_enabled', default: false, null: false
    t.datetime 'autoshutdown_last_check', null: false
    t.datetime 'autoshutdown_last_successful', null: false
    t.integer 'autoshutdown_minutes', default: 8, null: false
    t.index ['server_id'], name: 'index_minecrafts_on_server_id', unique: true
  end

  create_table 'scheduled_tasks', force: :cascade do |t|
    t.uuid 'server_id', null: false
    t.integer 'partition', null: false
    t.string 'action', null: false
    t.index ['partition'], name: 'index_scheduled_tasks_on_partition'
  end

  create_table 'server_logs', force: :cascade do |t|
    t.uuid 'server_id', null: false
    t.text 'message', null: false
    t.string 'debuginfo', limit: 255, null: false
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.index ['server_id'], name: 'index_server_logs_on_server_id'
  end

  create_table 'servers', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
    t.integer 'user_id', null: false
    t.string 'name', limit: 255, null: false
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.string 'domain', null: false
    t.string 'pending_operation'
    t.integer 'ssh_port', default: 4022, null: false
    t.string 'ssh_keys'
    t.integer 'setup_stage', default: 0, null: false
    t.integer 'remote_id'
    t.string 'remote_region_slug', null: false
    t.string 'remote_size_slug', null: false
    t.integer 'remote_snapshot_id'
    t.integer 'timezone_delta', default: 0, null: false
    t.string 'api_key', null: false
    t.boolean 'preserve_snapshot', default: false, null: false
    t.index ['domain'], name: 'index_servers_on_domain', unique: true
    t.index ['user_id'], name: 'index_servers_on_user_id'
  end

  create_table 'servers_users', force: :cascade do |t|
    t.uuid 'server_id'
    t.integer 'user_id'
    t.index ['server_id', 'user_id'], name: 'index_servers_users_on_server_id_and_user_id', unique: true
    t.index ['server_id'], name: 'index_servers_users_on_server_id'
    t.index ['user_id'], name: 'index_servers_users_on_user_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'email', limit: 255, default: '', null: false
    t.string 'encrypted_password', limit: 255, default: '', null: false
    t.string 'reset_password_token', limit: 255
    t.datetime 'reset_password_sent_at'
    t.datetime 'remember_created_at'
    t.integer 'sign_in_count', default: 0, null: false
    t.datetime 'current_sign_in_at'
    t.datetime 'last_sign_in_at'
    t.string 'current_sign_in_ip', limit: 255
    t.string 'last_sign_in_ip', limit: 255
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.string 'digital_ocean_api_key', limit: 255
    t.index ['email'], name: 'index_users_on_email', unique: true
    t.index ['reset_password_token'], name: 'index_users_on_reset_password_token', unique: true
  end

  create_table 'volumes', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.integer 'user_id', null: false
    t.uuid 'server_id'
    t.string 'name', null: false
    t.string 'status', null: false
    t.string 'remote_id'
    t.integer 'remote_size_gb', null: false
    t.string 'remote_region_slug', null: false
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['name'], name: 'index_volumes_on_name', unique: true
    t.index ['server_id'], name: 'index_volumes_on_server_id', unique: true
    t.index ['user_id'], name: 'index_volumes_on_user_id'
  end

  add_foreign_key 'minecrafts', 'servers', on_delete: :cascade
  add_foreign_key 'scheduled_tasks', 'servers', on_delete: :cascade
  add_foreign_key 'server_logs', 'servers', on_delete: :cascade
  add_foreign_key 'servers', 'users', on_delete: :cascade
  add_foreign_key 'servers_users', 'servers', on_delete: :cascade
  add_foreign_key 'servers_users', 'users', on_delete: :cascade
  add_foreign_key 'volumes', 'servers', on_delete: :nullify
  add_foreign_key 'volumes', 'users', on_delete: :cascade
end
