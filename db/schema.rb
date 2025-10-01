# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 20250940) do
  create_table "email_templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "subject", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_email_templates_on_name", unique: true
  end

  create_table "settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "configurable_type", null: false
    t.bigint "configurable_id", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["configurable_type", "configurable_id", "key"], name: "index_settings_on_resource_and_key", unique: true
    t.index ["configurable_type", "configurable_id"], name: "index_settings_on_configurable_type_and_configurable_id"
  end

  create_table "tasks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "priority"
    t.date "due_date"
    t.time "due_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "mobile"
    t.string "email", null: false
    t.string "account_name", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "activated", default: false, null: false
    t.string "activation_token"
    t.datetime "activated_at"
    t.index ["account_name"], name: "index_users_on_account_name"
    t.index ["activation_token"], name: "index_users_on_activation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["mobile"], name: "index_users_on_mobile", unique: true
  end

  add_foreign_key "tasks", "users"
end
