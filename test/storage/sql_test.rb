# encoding: UTF-8

require 'test_helper'
require 'storage/sql_schema'

module Diaspora
  class Application < Rails::Application
    def config.database_configuration
      {
        "development" => {
          "adapter" => "sqlite3",
          "database" => "test.db"
        }
      }
    end
  end
end

describe Vines::Storage::Sql do
  include SqlSchema

  before do
    @test_user = {
      :name => "test",
      :jid => "test@local.host",
      :email => "test@test.de",
      :password => "$2a$10$c2G6rHjGeamQIOFI0c1/b.4mvFBw4AfOtgVrAkO1QPMuAyporj5e6", # pppppp
      :token => "1234"
    }
    # create sql schema
    storage && create_schema(:force => true)

    Vines::Storage::Sql::User.new(
      username: @test_user[:name],
      email: @test_user[:email],
      encrypted_password: @test_user[:password],
      authentication_token: @test_user[:token]
    ).save
    Vines::Storage::Sql::Person.new(
      guid: "1697a4b0198901321e9b10e6ba921ce9",
      url: "http://remote.host/",
      serialized_public_key: "some pub key",
      diaspora_handle: "test2@remote.host"
    ).save
    Vines::Storage::Sql::Contact.new(
      user_id: 1,
      person_id: 1,
      sharing: true,
      receiving: true
    ).save
    Vines::Storage::Sql::Aspect.new(
      :user_id => 1,
      :name => "without_chat",
      :contacts_visible => true,
      :order_id => nil
    ).save
    Vines::Storage::Sql::AspectMembership.new(
      :aspect_id => 1, # without_chat
      :contact_id => 1 # person
    ).save
  end

  after do
    db = Rails.application.config.database_configuration["development"]["database"]
    File.delete(db) if File.exist?(db)
  end

  def test_aspect_chat_enabled
    fibered do
      db = storage
      user = db.find_user(@test_user[:jid])
      assert_equal 0, user.roster.length

      aspect = Vines::Storage::Sql::Aspect.where(:id => 1)
      aspect.update_all(
        :name => "with_chat",
        :chat_enabled => true
      )
      user = db.find_user(@test_user[:jid])
      assert_equal 1, user.roster.length
    end
  end

  def test_save_user
    fibered do
      db = storage
      user = Vines::User.new(
        jid: 'test2@test.de',
        name: 'test2@test.de',
        password: 'secret')
      db.save_user(user)
      assert_nil db.find_user('test2@test.de')
    end
  end

  def test_find_user
    fibered do
      db = storage
      user = db.find_user(nil)
      assert_nil user

      user = db.find_user(@test_user[:jid])
      assert (user != nil), "no user found"
      assert_equal @test_user[:name], user.name

      user = db.find_user(Vines::JID.new(@test_user[:jid]))
      assert (user != nil), "no user found"
      assert_equal @test_user[:name], user.name

      user = db.find_user(Vines::JID.new("#{@test_user[:jid]}/resource"))
      assert (user != nil), "no user found"
      assert_equal @test_user[:name], user.name
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
      user = db.authenticate(@test_user[:jid], "pppppp#{pepper}")
      assert (user != nil), "no user found"
      assert_equal @test_user[:name], user.name

      # user token auth
      user = db.authenticate(@test_user[:jid], @test_user[:token])
      assert (user != nil), "no user found"
      assert_equal @test_user[:name], user.name
    end
  end

  def test_find_fragment
    skip("not working probably")

    fibered do
      db = storage
      root = Nokogiri::XML(%q{<characters xmlns="urn:wonderland"/>}).root
      bad_name = Nokogiri::XML(%q{<not_characters xmlns="urn:wonderland"/>}).root
      bad_ns = Nokogiri::XML(%q{<characters xmlns="not:wonderland"/>}).root

      node = db.find_fragment(nil, nil)
      assert_nil node

      node = db.find_fragment('full@wonderland.lit', bad_name)
      assert_nil node

      node = db.find_fragment('full@wonderland.lit', bad_ns)
      assert_nil node

      node = db.find_fragment('full@wonderland.lit', root)
      assert (node != nil), "node should include fragment"
      assert_equal fragment.to_s, node.to_s

      node = db.find_fragment(Vines::JID.new('full@wonderland.lit'), root)
      assert (node != nil), "node should include fragment"
      assert_equal fragment.to_s, node.to_s

      node = db.find_fragment(Vines::JID.new('full@wonderland.lit/resource'), root)
      assert (node != nil), "node should include fragment"
      assert_equal fragment.to_s, node.to_s
    end
  end

  def test_save_fragment
    skip("not working probably")

    fibered do
      db = storage
      root = Nokogiri::XML(%q{<characters xmlns="urn:wonderland"/>}).root
      db.save_fragment('test@test.de/resource1', fragment)
      node = db.find_fragment('test@test.de', root)
      assert (node != nil), "node should include fragment"
      assert_equal fragment.to_s, node.to_s
    end
  end
end
