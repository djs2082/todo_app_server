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

ActiveRecord::Schema[7.1].define(version: 202510266) do
  create_table "email_templates", charset: "utf8mb3", force: :cascade do |t|
    t.string "name", null: false
    t.string "subject", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_email_templates_on_name", unique: true
  end

  create_table "events", charset: "utf8mb3", force: :cascade do |t|
    t.string "kind", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "initiator_type"
    t.bigint "initiator_id"
    t.json "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_events_on_created_at"
    t.index ["initiator_type", "initiator_id"], name: "index_events_on_initiator_type_and_initiator_id"
    t.index ["kind", "subject_type", "subject_id"], name: "index_events_on_kind_and_subject"
    t.index ["kind"], name: "index_events_on_kind"
    t.index ["subject_type", "subject_id"], name: "index_events_on_subject_type_and_subject_id"
  end

  create_table "jwt_blacklists", charset: "utf8mb3", force: :cascade do |t|
    t.string "jti", null: false
    t.string "token_type", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_jwt_blacklists_on_expires_at"
    t.index ["jti"], name: "index_jwt_blacklists_on_jti", unique: true
  end

  create_table "settings", charset: "utf8mb3", force: :cascade do |t|
    t.string "configurable_type", null: false
    t.bigint "configurable_id", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["configurable_type", "configurable_id", "key"], name: "index_settings_on_resource_and_key", unique: true
    t.index ["configurable_type", "configurable_id"], name: "index_settings_on_configurable_type_and_configurable_id"
  end

  create_table "task_events", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "eventable_type", null: false
    t.bigint "eventable_id", null: false
    t.string "event_type", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_task_events_on_event_type"
    t.index ["eventable_type", "eventable_id"], name: "index_task_events_on_eventable"
    t.index ["eventable_type", "eventable_id"], name: "index_task_events_on_eventable_type_and_eventable_id"
    t.index ["task_id", "created_at"], name: "index_task_events_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_events_on_task_id"
  end

  create_table "task_pauses", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.datetime "paused_at", null: false
    t.datetime "resumed_at"
    t.integer "work_duration", default: 0
    t.string "reason"
    t.text "comment"
    t.integer "progress_percentage", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reason"], name: "index_task_pauses_on_reason"
    t.index ["task_id", "paused_at"], name: "index_task_pauses_on_task_id_and_paused_at"
    t.index ["task_id"], name: "index_task_pauses_on_task_id"
  end

  create_table "task_snapshots", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "snapshotable_type", null: false
    t.bigint "snapshotable_id", null: false
    t.string "snapshot_type", null: false
    t.json "state_data"
    t.integer "progress_at_snapshot"
    t.integer "total_time_at_snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["snapshotable_type", "snapshotable_id"], name: "index_task_snapshots_on_snapshotable"
    t.index ["task_id", "created_at"], name: "index_task_snapshots_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_snapshots_on_task_id"
  end

  create_table "tasks", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "due_date_time"
    t.integer "status", default: 0, null: false
    t.integer "total_working_time", default: 0, null: false
    t.datetime "started_at"
    t.datetime "last_resumed_at"
    t.index ["due_date_time"], name: "index_tasks_on_due_date_time"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", charset: "utf8mb3", force: :cascade do |t|
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
    t.string "reset_password_token"
    t.datetime "reset_password_expires_at"
    t.datetime "last_singin_at"
    t.integer "signin_count", default: 0, null: false
    t.index ["account_name"], name: "index_users_on_account_name"
    t.index ["activation_token"], name: "index_users_on_activation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_singin_at"], name: "index_users_on_last_singin_at"
    t.index ["mobile"], name: "index_users_on_mobile", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "task_events", "tasks"
  add_foreign_key "task_pauses", "tasks"
  add_foreign_key "task_snapshots", "tasks"
  add_foreign_key "tasks", "users"
end
