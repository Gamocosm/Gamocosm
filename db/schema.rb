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

ActiveRecord::Schema.define(version: 20140922050912) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "minecrafts", id: :uuid, default: "uuid_generate_v4()", force: true do |t|
    t.integer  "user_id",                    null: false
    t.string   "name",                       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "minecraft_wrapper_password", null: false
  end

  add_index "minecrafts", ["user_id"], name: "index_minecrafts_on_user_id", using: :btree

  create_table "minecrafts_users", force: true do |t|
    t.uuid    "minecraft_id"
    t.integer "user_id"
  end

  add_index "minecrafts_users", ["minecraft_id", "user_id"], name: "index_minecrafts_users_on_minecraft_id_and_user_id", unique: true, using: :btree
  add_index "minecrafts_users", ["minecraft_id"], name: "index_minecrafts_users_on_minecraft_id", using: :btree
  add_index "minecrafts_users", ["user_id"], name: "index_minecrafts_users_on_user_id", using: :btree

  create_table "server_logs", force: true do |t|
    t.uuid     "minecraft_id", null: false
    t.string   "message",      null: false
    t.string   "debuginfo",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "server_logs", ["minecraft_id"], name: "index_server_logs_on_minecraft_id", using: :btree

  create_table "servers", force: true do |t|
    t.integer  "remote_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid     "minecraft_id",                     null: false
    t.string   "do_region_slug",                   null: false
    t.string   "do_size_slug",                     null: false
    t.integer  "do_saved_snapshot_id"
    t.integer  "remote_setup_stage",   default: 0, null: false
    t.string   "pending_operation"
  end

  add_index "servers", ["minecraft_id"], name: "index_servers_on_minecraft_id", unique: true, using: :btree

  create_table "users", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "digital_ocean_api_key"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  add_foreign_key "minecrafts", "users", name: "minecrafts_user_id_fk", dependent: :delete

  add_foreign_key "minecrafts_users", "minecrafts", name: "minecrafts_users_minecraft_id_fk", dependent: :delete
  add_foreign_key "minecrafts_users", "users", name: "minecrafts_users_user_id_fk", dependent: :delete

  add_foreign_key "server_logs", "minecrafts", name: "server_logs_minecraft_id_fk", dependent: :delete

  add_foreign_key "servers", "minecrafts", name: "servers_minecraft_id_fk", dependent: :delete

end
