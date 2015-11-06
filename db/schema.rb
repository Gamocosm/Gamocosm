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

ActiveRecord::Schema.define(version: 20151106024157) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "minecrafts", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "server_id",                                    null: false
    t.string   "flavour",                                      null: false
    t.string   "mcsw_password",                                null: false
    t.boolean  "autoshutdown_enabled",         default: false, null: false
    t.datetime "autoshutdown_last_check",                      null: false
    t.datetime "autoshutdown_last_successful",                 null: false
  end

  add_index "minecrafts", ["server_id"], name: "index_minecrafts_on_server_id", unique: true, using: :btree

  create_table "scheduled_tasks", force: :cascade do |t|
    t.uuid    "server_id", null: false
    t.integer "partition", null: false
    t.string  "action",    null: false
  end

  add_index "scheduled_tasks", ["partition"], name: "index_scheduled_tasks_on_partition", using: :btree

  create_table "server_logs", force: :cascade do |t|
    t.uuid     "server_id",              null: false
    t.text     "message",                null: false
    t.string   "debuginfo",  limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "server_logs", ["server_id"], name: "index_server_logs_on_server_id", using: :btree

  create_table "servers", id: :uuid, default: "uuid_generate_v4()", force: :cascade do |t|
    t.integer  "user_id",                                       null: false
    t.string   "name",               limit: 255,                null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "domain",                                        null: false
    t.string   "pending_operation"
    t.integer  "ssh_port",                       default: 4022, null: false
    t.string   "ssh_keys"
    t.integer  "setup_stage",                    default: 0,    null: false
    t.integer  "remote_id"
    t.string   "remote_region_slug",                            null: false
    t.string   "remote_size_slug",                              null: false
    t.integer  "remote_snapshot_id"
    t.integer  "timezone_delta",                 default: 0,    null: false
  end

  add_index "servers", ["domain"], name: "index_servers_on_domain", unique: true, using: :btree
  add_index "servers", ["user_id"], name: "index_servers_on_user_id", using: :btree

  create_table "servers_users", force: :cascade do |t|
    t.uuid    "server_id"
    t.integer "user_id"
  end

  add_index "servers_users", ["server_id", "user_id"], name: "index_servers_users_on_server_id_and_user_id", unique: true, using: :btree
  add_index "servers_users", ["server_id"], name: "index_servers_users_on_server_id", using: :btree
  add_index "servers_users", ["user_id"], name: "index_servers_users_on_user_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "", null: false
    t.string   "encrypted_password",     limit: 255, default: "", null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "digital_ocean_api_key",  limit: 255
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  add_foreign_key "minecrafts", "servers", on_delete: :cascade
  add_foreign_key "scheduled_tasks", "servers", on_delete: :cascade
  add_foreign_key "server_logs", "servers", on_delete: :cascade
  add_foreign_key "servers", "users", on_delete: :cascade
  add_foreign_key "servers_users", "servers", on_delete: :cascade
  add_foreign_key "servers_users", "users", on_delete: :cascade
end
