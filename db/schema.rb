# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140512034335) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "droplets", force: true do |t|
    t.integer  "remote_id"
    t.integer  "remote_size_id"
    t.integer  "remote_region_id"
    t.inet     "ip_address"
    t.string   "remote_status"
    t.datetime "last_synced"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "minecraft_server_id"
  end

  add_index "droplets", ["minecraft_server_id"], name: "index_droplets_on_minecraft_server_id", unique: true, using: :btree

  create_table "minecraft_servers", id: :uuid, default: "uuid_generate_v4()", force: true do |t|
    t.integer  "user_id"
    t.string   "name"
    t.integer  "saved_snapshot_id"
    t.string   "pending_operation"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "digital_ocean_droplet_size_id"
    t.boolean  "should_destroy",                  default: false, null: false
    t.integer  "remote_setup_stage",              default: 0
    t.string   "minecraft_wrapper_password"
    t.integer  "digital_ocean_droplet_region_id"
    t.integer  "remote_ssh_setup_stage",          default: 0,     null: false
    t.integer  "digital_ocean_pending_event_id"
  end

  add_index "minecraft_servers", ["user_id"], name: "index_minecraft_servers_on_user_id", using: :btree

  create_table "minecraft_servers_users", force: true do |t|
    t.uuid    "minecraft_server_id"
    t.integer "user_id"
  end

  add_index "minecraft_servers_users", ["minecraft_server_id", "user_id"], name: "index_mc_servers_users_on_mc_server_id_and_user_id", unique: true, using: :btree
  add_index "minecraft_servers_users", ["minecraft_server_id"], name: "index_minecraft_servers_users_on_minecraft_server_id", using: :btree
  add_index "minecraft_servers_users", ["user_id"], name: "index_minecraft_servers_users_on_user_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "email",                   default: "", null: false
    t.string   "encrypted_password",      default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",           default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "digital_ocean_client_id"
    t.string   "digital_ocean_api_key"
    t.integer  "digital_ocean_event_id"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  add_foreign_key "droplets", "minecraft_servers", name: "droplets_minecraft_server_id_fk", dependent: :delete

  add_foreign_key "minecraft_servers", "users", name: "minecraft_servers_user_id_fk", dependent: :delete

  add_foreign_key "minecraft_servers_users", "minecraft_servers", name: "minecraft_servers_users_minecraft_server_id_fk", dependent: :delete
  add_foreign_key "minecraft_servers_users", "users", name: "minecraft_servers_users_user_id_fk", dependent: :delete

end
