module SqlSchema
  def fibered
    EM.run do
      Fiber.new do
        yield
        EM.stop
      end.resume
    end
  end

  def fragment_id
    Digest::SHA1.hexdigest("characters:urn:wonderland")
  end

  def fragment
    Nokogiri::XML(%q{
      <characters xmlns="urn:wonderland">
        <character>Alice</character>
      </characters>
    }.strip).root
  end

  def storage
    Vines::Storage::Sql.new
  end

  def create_schema(args={})
    args[:force] ||= false

    # disable stdout logging
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table "people", :force => true do |t|
        t.string   "guid",                                     :null => false
        t.text     "url",                                      :null => false
        t.string   "diaspora_handle",                          :null => false
        t.text     "serialized_public_key",                    :null => false
        t.integer  "owner_id"
        t.datetime "created_at",                               :null => false
        t.datetime "updated_at",                               :null => false
        t.boolean  "closed_account",        :default => false
        t.integer  "fetch_status",          :default => 0
      end

      add_index "people", ["diaspora_handle"], :name => "index_people_on_diaspora_handle", :unique => true
      add_index "people", ["guid"], :name => "index_people_on_guid", :unique => true
      add_index "people", ["owner_id"], :name => "index_people_on_owner_id", :unique => true

      create_table "profiles", force: true do |t|
        t.string   "diaspora_handle"
        t.string   "first_name",       limit: 127
        t.string   "last_name",        limit: 127
        t.string   "image_url"
        t.string   "image_url_small"
        t.string   "image_url_medium"
        t.date     "birthday"
        t.string   "gender"
        t.text     "bio"
        t.boolean  "searchable",                   default: true,  null: false
        t.integer  "person_id",                                    null: false
        t.datetime "created_at",                                   null: false
        t.datetime "updated_at",                                   null: false
        t.string   "location"
        t.string   "full_name",        limit: 70
        t.boolean  "nsfw",                         default: false
      end

      add_index "profiles", ["full_name", "searchable"], name: "index_profiles_on_full_name_and_searchable", using: :btree
      add_index "profiles", ["full_name"], name: "index_profiles_on_full_name", using: :btree
      add_index "profiles", ["person_id"], name: "index_profiles_on_person_id", using: :btree

      create_table "aspects", :force => true do |t|
        t.string   "name",                               :null => false
        t.integer  "user_id",                            :null => false
        t.datetime "created_at",                         :null => false
        t.datetime "updated_at",                         :null => false
        t.boolean  "contacts_visible", :default => true, :null => false
        t.integer  "order_id"
        t.boolean  "chat_enabled",     default: false
      end
      
      add_index "aspects", ["user_id", "contacts_visible"], :name => "index_aspects_on_user_id_and_contacts_visible"
      add_index "aspects", ["user_id"], :name => "index_aspects_on_user_id"

      create_table "aspect_memberships", :force => true do |t|
        t.integer  "aspect_id",  :null => false
        t.integer  "contact_id", :null => false
        t.datetime "created_at", :null => false
        t.datetime "updated_at", :null => false
      end
      
      add_index "aspect_memberships", ["aspect_id", "contact_id"], :name => "index_aspect_memberships_on_aspect_id_and_contact_id", :unique => true
      add_index "aspect_memberships", ["aspect_id"], :name => "index_aspect_memberships_on_aspect_id"
      add_index "aspect_memberships", ["contact_id"], :name => "index_aspect_memberships_on_contact_id"

      create_table "contacts", :force => true do |t|
        t.integer  "user_id",                       :null => false
        t.integer  "person_id",                     :null => false
        t.datetime "created_at",                    :null => false
        t.datetime "updated_at",                    :null => false
        t.boolean  "sharing",    :default => false, :null => false
        t.boolean  "receiving",  :default => false, :null => false
      end
      
      add_index "contacts", ["person_id"], :name => "index_contacts_on_person_id"
      add_index "contacts", ["user_id", "person_id"], :name => "index_contacts_on_user_id_and_person_id", :unique => true

      create_table "chat_contacts", :force => true do |t|
        t.integer "user_id", :null => false
        t.string "jid", :null => false
        t.string "name"
        t.string "ask", :limit => 128
        t.string "subscription", :limit => 128, :null => false
        t.text "groups"
      end
      
      add_index "chat_contacts", ["user_id", "jid"], :name => "index_chat_contacts_on_user_id_and_jid", :unique => true
      
      create_table "chat_fragments", :force => true do |t|
        t.integer "user_id", :null => false
        t.string "root", :limit => 256, :null => false
        t.string "namespace", :limit => 256, :null => false
        t.text "xml", :null => false
      end
      
      add_index "chat_fragments", ["user_id"], :name => "index_chat_fragments_on_user_id", :unique => true

      create_table "chat_offline_messages", force: true do |t|
        t.string "from", null: false
        t.string "to", null: false
        t.text "message", null: false
        t.datetime "created_at", null: false
      end

      create_table "users", :force => true do |t|
        t.string   "username"
        t.text     "serialized_private_key"
        t.boolean  "getting_started",                                   :default => true,  :null => false
        t.boolean  "disable_mail",                                      :default => false, :null => false
        t.string   "language"
        t.string   "email",                                             :default => "",    :null => false
        t.string   "encrypted_password",                                :default => "",    :null => false
        t.string   "invitation_token",                   :limit => 60
        t.datetime "invitation_sent_at"
        t.string   "reset_password_token"
        t.datetime "remember_created_at"
        t.integer  "sign_in_count",                                     :default => 0
        t.datetime "current_sign_in_at"
        t.datetime "last_sign_in_at"
        t.string   "current_sign_in_ip"
        t.string   "last_sign_in_ip"
        t.datetime "created_at",                                                           :null => false
        t.datetime "updated_at",                                                           :null => false
        t.string   "invitation_service",                 :limit => 127
        t.string   "invitation_identifier",              :limit => 127
        t.integer  "invitation_limit"
        t.integer  "invited_by_id"
        t.string   "invited_by_type"
        t.string   "authentication_token",               :limit => 30
        t.string   "unconfirmed_email"
        t.string   "confirm_email_token",                :limit => 30
        t.datetime "locked_at"
        t.boolean  "show_community_spotlight_in_stream",                :default => true,  :null => false
        t.boolean  "auto_follow_back",                                  :default => false
        t.integer  "auto_follow_back_aspect_id"
        t.text     "hidden_shareables"
        t.datetime "reset_password_sent_at"
        t.datetime "last_seen"
      end
      
      add_index "users", ["authentication_token"], :name => "index_users_on_authentication_token", :unique => true
      add_index "users", ["email"], :name => "index_users_on_email"
      add_index "users", ["invitation_service", "invitation_identifier"], :name => "index_users_on_invitation_service_and_invitation_identifier", :unique => true
      add_index "users", ["invitation_token"], :name => "index_users_on_invitation_token"
      add_index "users", ["username"], :name => "index_users_on_username", :unique => true
      
      #add_foreign_key "aspect_memberships", "aspects", name: "aspect_memberships_aspect_id_fk", dependent: :delete
      #add_foreign_key "aspect_memberships", "contacts", name: "aspect_memberships_contact_id_fk", dependent: :delete
      #add_foreign_key "contacts", "people", name: "contacts_person_id_fk", dependent: :delete
    end
  end
end
