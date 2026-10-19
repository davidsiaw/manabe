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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "admins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.datetime "locked_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", precision: nil
    t.index ["confirmation_token"], name: "index_admins_on_confirmation_token", unique: true
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_admins_on_unlock_token", unique: true
  end

  create_table "completions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "learner_id", null: false
    t.string "course_id", null: false
    t.string "problem_id", null: false
    t.datetime "updated_at"
    t.integer "round", default: 1, null: false
    t.index ["learner_id", "course_id", "round", "problem_id"], name: "idx_on_learner_id_course_id_round_problem_id_c7ed3357c9", unique: true
  end

  create_table "learner_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "learner_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at"
    t.index ["learner_id"], name: "index_learner_sessions_on_learner_id"
    t.index ["token_digest"], name: "index_learner_sessions_on_token_digest", unique: true
  end

  create_table "learners", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "updated_at"
    t.citext "email"
    t.string "webauthn_id"
    t.index ["email"], name: "index_learners_on_email", unique: true
    t.index ["webauthn_id"], name: "index_learners_on_webauthn_id", unique: true
  end

  create_table "passkey_challenges", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "challenge", null: false
    t.string "purpose", null: false
    t.uuid "learner_id"
    t.citext "email"
    t.datetime "expires_at", null: false
    t.datetime "updated_at"
    t.index ["challenge"], name: "index_passkey_challenges_on_challenge", unique: true
    t.index ["learner_id"], name: "index_passkey_challenges_on_learner_id"
  end

  create_table "passkeys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "learner_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.datetime "updated_at"
    t.index ["external_id"], name: "index_passkeys_on_external_id", unique: true
    t.index ["learner_id"], name: "index_passkeys_on_learner_id"
  end

  create_table "revisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "learner_id", null: false
    t.string "course_id", null: false
    t.integer "number", null: false
    t.datetime "updated_at"
    t.index ["learner_id", "course_id", "number"], name: "index_revisions_on_learner_id_and_course_id_and_number", unique: true
  end

  create_table "versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "event", null: false
    t.uuid "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "completions", "learners"
  add_foreign_key "learner_sessions", "learners"
  add_foreign_key "passkey_challenges", "learners"
  add_foreign_key "passkeys", "learners"
  add_foreign_key "revisions", "learners"
end
