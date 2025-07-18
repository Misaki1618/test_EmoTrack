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

ActiveRecord::Schema[7.1].define(version: 2024_09_03_030005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "counts", force: :cascade do |t|
    t.integer "c"
  end

  create_table "emotions", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "dissatisfaction"
    t.integer "energy"
    t.integer "stress"
    t.text "diary"
    t.string "emotion_name"
    t.string "emotion_type"
    t.string "status"
    t.string "s"
    t.string "d"
    t.string "e"
    t.index ["user_id"], name: "index_emotions_on_user_id"
  end

  create_table "musics", force: :cascade do |t|
    t.bigint "user_id"
    t.string "url"
    t.string "name"
    t.boolean "favorite"
    t.integer "tempo"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_musics_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "emotions", "users"
  add_foreign_key "musics", "users"
end
