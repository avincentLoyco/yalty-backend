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

ActiveRecord::Schema.define(version: 20150907082834) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"
  enable_extension "hstore"

  create_table "account_users", force: :cascade do |t|
    t.string   "email",           null: false
    t.string   "password_digest", null: false
    t.integer  "account_id",      null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "account_users", ["account_id"], name: "index_account_users_on_account_id", using: :btree
  add_index "account_users", ["email", "account_id"], name: "index_account_users_on_email_and_account_id", unique: true, using: :btree

  create_table "accounts", force: :cascade do |t|
    t.string   "subdomain",    null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "company_name"
  end

  add_index "accounts", ["subdomain"], name: "index_accounts_on_subdomain", unique: true, using: :btree

  create_table "employee_attribute_definitions", force: :cascade do |t|
    t.string   "name",                           null: false
    t.string   "label",                          null: false
    t.boolean  "system",         default: false, null: false
    t.string   "attribute_type",                 null: false
    t.hstore   "validation"
    t.integer  "account_id",                     null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "employee_attribute_definitions", ["account_id"], name: "index_employee_attribute_definitions_on_account_id", using: :btree
  add_index "employee_attribute_definitions", ["name", "account_id"], name: "index_employee_attribute_definitions_on_name_and_account_id", unique: true, using: :btree

  create_table "employee_attribute_versions", force: :cascade do |t|
    t.hstore   "data"
    t.integer  "employee_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.integer  "attribute_definition_id"
    t.integer  "employee_event_id"
  end

  add_index "employee_attribute_versions", ["attribute_definition_id"], name: "index_employee_attribute_versions_on_attribute_definition_id", using: :btree
  add_index "employee_attribute_versions", ["employee_event_id"], name: "index_employee_attribute_versions_on_employee_event_id", using: :btree
  add_index "employee_attribute_versions", ["employee_id"], name: "index_employee_attribute_versions_on_employee_id", using: :btree

  create_table "employee_events", force: :cascade do |t|
    t.integer  "employee_id"
    t.datetime "effective_at"
    t.text     "comment"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "employee_events", ["employee_id"], name: "index_employee_events_on_employee_id", using: :btree

  create_table "employees", force: :cascade do |t|
    t.uuid     "uuid",       default: "uuid_generate_v4()"
    t.integer  "account_id"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
  end

  add_index "employees", ["account_id"], name: "index_employees_on_account_id", using: :btree
  add_index "employees", ["uuid", "account_id"], name: "index_employees_on_uuid_and_account_id", unique: true, using: :btree

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id", null: false
    t.integer  "application_id",    null: false
    t.string   "token",             null: false
    t.integer  "expires_in",        null: false
    t.text     "redirect_uri",      null: false
    t.datetime "created_at",        null: false
    t.datetime "revoked_at"
    t.string   "scopes"
  end

  add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true, using: :btree

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id"
    t.string   "token",             null: false
    t.string   "refresh_token"
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",        null: false
    t.string   "scopes"
  end

  add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true, using: :btree
  add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id", using: :btree
  add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true, using: :btree

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",                      null: false
    t.string   "uid",                       null: false
    t.string   "secret",                    null: false
    t.text     "redirect_uri",              null: false
    t.string   "scopes",       default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true, using: :btree

  add_foreign_key "account_users", "accounts", on_delete: :cascade
  add_foreign_key "employee_attribute_definitions", "accounts", on_delete: :cascade
  add_foreign_key "employee_attribute_versions", "employee_attribute_definitions", column: "attribute_definition_id", on_delete: :cascade
  add_foreign_key "employee_attribute_versions", "employee_events"
  add_foreign_key "employee_attribute_versions", "employees", on_delete: :cascade
  add_foreign_key "employee_events", "employees", on_delete: :cascade
  add_foreign_key "employees", "accounts", on_delete: :cascade
end
