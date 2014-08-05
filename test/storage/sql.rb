# encoding: UTF-8

require 'test_helper'
require 'storage/sql_schema'

class AppConfig
  def self.adapter; "sqlite3"; end
  def self.database; "test.db"; end
end

describe Vines::Storage::Sql do
  include SqlSchema

  before do
    storage && create_schema(:force => true)
    
    Vines::Storage::Sql::User.new(
      username: "test",
      email: "test@test.de",
      encrypted_password: "$2a$10$c2G6rHjGeamQIOFI0c1/b.4mvFBw4AfOtgVrAkO1QPMuAyporj5e6", # pppppp
      authentication_token: "1234"
    ).save
  end

  after do
    File.delete(AppConfig.database) if File.exist?(AppConfig.database)
  end

  def test_find_user
    fibered do
      db = storage
      user = db.find_user(nil)
      assert_nil user

      user = db.find_user("test@local.host")
      assert (user != nil), "no user found"
      assert_equal "test", user.name

      user = db.find_user(Vines::JID.new("test@local.host"))
      assert (user != nil), "no user found"
      assert_equal "test", user.name

      user = db.find_user(Vines::JID.new("test@local.host/resource"))
      assert (user != nil), "no user found"
      assert_equal "test", user.name
    end
  end

  def test_authenticate
    fibered do
      db = storage

      assert_nil db.authenticate(nil, nil)
      assert_nil db.authenticate(nil, "secret")
      assert_nil db.authenticate("bogus", nil)

      # user credential auth
      pepper = "065eb8798b181ff0ea2c5c16aee0ff8b70e04e2ee6bd6e08b49da46924223e39127d5335e466207d42bf2a045c12be5f90e92012a4f05f7fc6d9f3c875f4c95b"
      user = db.authenticate("test@test.de", "pppppp#{pepper}")
      assert (user != nil), "no user found"
      assert_equal "test", user.name

      # user token auth
      user = db.authenticate("test@test.de", "1234")
      assert (user != nil), "no user found"
      assert_equal "test", user.name
    end
  end
end
