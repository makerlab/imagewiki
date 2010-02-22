# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 6) do

  create_table "note_users", :force => true do |t|
    t.integer   "note_id"
    t.integer   "user_id"
    t.integer   "group_id"
    t.string    "role"
    t.timestamp "modified_at"
  end

  create_table "note_visitors", :force => true do |t|
    t.integer   "note_id"
    t.integer   "user_id"
    t.timestamp "modified_at"
  end

  create_table "notes", :force => true do |t|
    t.string    "type"
    t.string    "kind"
    t.string    "uuid"
    t.string    "provenance"
    t.integer   "permissions"
    t.integer   "statebits"
    t.integer   "owner_id"
    t.integer   "related_id"
    t.string    "title"
    t.string    "link"
    t.text      "description"
    t.string    "depiction"
    t.string    "location"
    t.string    "tagstring"
    t.float     "lat"
    t.float     "lon"
    t.float     "rad"
    t.integer   "depth"
    t.integer   "score"
    t.timestamp "begins"
    t.timestamp "ends"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.string    "photo_file_name"
    t.string    "photo_content_type"
    t.integer   "photo_file_size"
  end

  create_table "relations", :force => true do |t|
    t.string    "type"
    t.string    "kind"
    t.text      "value"
    t.integer   "note_id"
    t.integer   "sibling_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "sessions", :force => true do |t|
    t.string    "session_id", :null => false
    t.text      "data"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "transits", :force => true do |t|
    t.integer "position"
    t.integer "word_id"
    t.integer "note_id"
  end

  create_table "users", :force => true do |t|
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.string    "login",                                 :null => false
    t.string    "email",                                 :null => false
    t.string    "crypted_password",                      :null => false
    t.string    "password_salt",                         :null => false
    t.string    "persistence_token",                     :null => false
    t.integer   "login_count",        :default => 0,     :null => false
    t.timestamp "last_request_at"
    t.timestamp "last_login_at"
    t.timestamp "current_login_at"
    t.string    "last_login_ip"
    t.string    "current_login_ip"
    t.boolean   "admin",              :default => false
    t.string    "photo_file_name"
    t.string    "photo_content_type"
    t.integer   "photo_file_size"
  end

  add_index "users", ["last_request_at"], :name => "index_users_on_last_request_at"
  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"

  create_table "words", :force => true do |t|
    t.string  "stem",       :default => "''::character varying"
    t.string  "word",       :default => "''::character varying"
    t.string  "provenance", :default => "''::character varying"
    t.integer "frequency",  :default => 0
  end

end
