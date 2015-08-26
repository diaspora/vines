# encoding: UTF-8

module Vines
  class Storage
    class Sql < Storage
      include Vines::Log

      register :sql

      class Profile < ActiveRecord::Base
        belongs_to :person
      end
      class Person < ActiveRecord::Base
        has_one :profile

        def local?
          !self.owner_id.nil?
        end

        def name(opts = {})
          self.profile.first_name.blank? && self.profile.last_name.blank? ?
            self.diaspora_handle : "#{self.profile.first_name.to_s.strip} #{self.profile.last_name.to_s.strip}".strip
        end
      end

      class Aspect < ActiveRecord::Base
        belongs_to :users

        has_many :aspect_memberships
        has_many :contacts
      end

      class AspectMembership < ActiveRecord::Base
        belongs_to :aspect
        belongs_to :contact

        has_one :users, :through => :contact
        has_one :person, :through => :contact
      end

      class Contact < ActiveRecord::Base
        scope :chat_enabled, -> {
          joins(:aspects)
          .where("aspects.chat_enabled = ?", true)
          .group("person_id, contacts.id")
        }

        belongs_to :users
        belongs_to :person

        has_many :aspect_memberships
        has_many :aspects, :through => :aspect_memberships
      end

      class User < ActiveRecord::Base
        has_many :contacts
        has_many :chat_contacts, :dependent => :destroy
        has_many :fragments, :dependent => :delete_all

        has_one :person, :foreign_key => :owner_id
      end

      class ChatOfflineMessage < ActiveRecord::Base; end

      class ChatContact < ActiveRecord::Base
        belongs_to :users
      end

      class ChatFragment < ActiveRecord::Base
        belongs_to :users
      end

      # Wrap the method with ActiveRecord connection pool logic, so we properly
      # return connections to the pool when we're finished with them. This also
      # defers the original method by pushing it onto the EM thread pool because
      # ActiveRecord uses blocking IO.
      def self.with_connection(method, args={})
        deferrable = args.key?(:defer) ? args[:defer] : true
        old = instance_method(method)
        define_method method do |*args|
          ActiveRecord::Base.connection_pool.with_connection do
            old.bind(self).call(*args)
          end
        end
        defer(method) if deferrable
      end

      def initialize(&block)
        @config = {}
        unless defined? Rails
          raise "You configured diaspora-sql adapter without Diaspora environment"
        end

        config = Rails.application.config.database_configuration[Rails.env]
        %w[adapter database host port username password].each do |key|
          @config[key.to_sym] = config[key]
        end

        required = [:adapter, :database]
        required << [:host, :port] unless @config[:adapter] == 'sqlite3'
        required.flatten.each {|key| raise "Must provide #{key}" unless @config[key] }
        [:username, :password].each {|key| @config.delete(key) if empty?(@config[key]) }
        establish_connection
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        xuser = user_by_jid(jid)
        return Vines::User.new(jid: jid).tap do |user|
          user.name, user.password, user.token =
            xuser.username,
            xuser.encrypted_password,
            xuser.authentication_token

          # add diaspora contacts
          xuser.contacts.chat_enabled.each do |contact|
            handle = contact.person.diaspora_handle
            profile = contact.person.profile
            name = "#{profile.first_name} #{profile.last_name}"
            name = handle.gsub(/\@.*?$/, '') if name.strip.empty?
            ask, subscription, groups = get_diaspora_flags(contact)
            user.roster << Vines::Contact.new(
              jid: handle,
              name: name,
              subscription: subscription,
              from_diaspora: true,
              groups: groups,
              ask: ask)
          end

          # add external contacts
          xuser.chat_contacts.each do |contact|
            user.roster << Vines::Contact.new(
              jid: contact.jid,
              name: contact.name,
              subscription: contact.subscription,
              groups: get_external_groups,
              ask: contact.ask)
          end
        end if xuser
      end
      with_connection :find_user

      def authenticate(username, password)
        user = find_user(username)

        pepper = "#{password}#{Devise.pepper}" rescue password
        dbhash = BCrypt::Password.new(user.password) rescue nil
        hash = BCrypt::Engine.hash_secret(pepper, dbhash.salt) rescue nil

        userAuth = ((hash && dbhash) && hash == dbhash)
        tokenAuth = ((password && user) && password == user.token)
        (tokenAuth || userAuth)? user : nil
      end

      def save_user(user)
        # it is not possible to register an account via xmpp server
        xuser = user_by_jid(user.jid) || return

        # remove deleted contacts from roster
        xuser.chat_contacts.delete(xuser.chat_contacts.select do |contact|
          !user.contact?(contact.jid)
        end)

        # update contacts
        xuser.chat_contacts.each do |contact|
          fresh = user.contact(contact.jid)
          contact.update_attributes(
            name: fresh.name,
            ask: fresh.ask,
            subscription: fresh.subscription)
        end

        # add new contacts to roster
        jids = xuser.chat_contacts.map {|c|
          c.jid if (c.user_id == xuser.id)
        }.compact
        user.roster.select {|contact|
          unless contact.from_diaspora
            xuser.chat_contacts.build(
              user_id: xuser.id,
              jid: contact.jid.bare.to_s,
              name: contact.name,
              ask: contact.ask,
              subscription: contact.subscription) unless jids.include?(contact.jid.bare.to_s)
          end
        }
        xuser.save
      end
      with_connection :save_user

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return nil if jid.empty?
        person = Sql::Person.find_by_diaspora_handle(jid)
        return nil unless person.nil? || person.local?

        build_vcard(person)
      end
      with_connection :find_vcard

      def save_vcard(jid, card)
        # NOTE this is not supported. If you'd like to change your
        # vcard details you can edit it via diaspora-web-interface
        nil
      end
      with_connection :save_vcard

      def find_messages(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        results = Hash.new
        Sql::ChatOfflineMessage.where(:to => jid).each do |r|
          results[r.id] = {
            :from => r.from,
            :to => r.to,
            :message => r.message,
            :created_at => r.created_at
          }
        end
        return results
      end
      with_connection :find_messages

      def save_message(from, to, msg)
        return if from.empty? || to.empty? || msg.empty?
        com = Sql::ChatOfflineMessage
        current = com.count(:to => to)
        unless current < Config.instance.max_offline_msgs
          com.where(:to => to)
             .order(created_at: :asc)
             .first
             .delete
        end
        com.create(:from => from, :to => to, :message => msg)
      end
      with_connection :save_message

      def destroy_message(id)
        id = id.to_i rescue nil
        return if id.nil?
        Sql::ChatOfflineMessage.find(id).destroy
      end
      with_connection :destroy_message

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        if fragment = fragment_by_jid(jid, node)
          Nokogiri::XML(fragment.xml).root rescue nil
        end
      end
      with_connection :find_fragment

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        fragment = fragment_by_jid(jid, node) ||
        Sql::ChatFragment.new(
          user: user_by_jid(jid),
          root: node.name,
          namespace: node.namespace.href)
        fragment.xml = node.to_xml
        fragment.save
      end
      with_connection :save_fragment

      def find_avatar_by_jid(jid)
        jid = JID.new(jid).bare.to_s
        return nil if jid.empty?

        person = Sql::Person.find_by_diaspora_handle(jid)
        return nil if person.nil?
        return nil if person.profile.nil?
        return nil unless person.local?
        person.profile.image_url
      end
      with_connection :find_avatar_by_jid

      private
        def establish_connection
          ActiveRecord::Base.logger = log # using vines logger
          ActiveRecord::Base.establish_connection(@config)
        end

        def user_by_jid(jid)
          name = JID.new(jid).node
          Sql::User.find_by_username(name)
        end

        def get_external_groups
          # TODO Make the group name configurable by the user
          # https://github.com/diaspora/vines/issues/39
          group_name = "External XMPP Contacts"
          matches = Sql::Aspect.where(:name => group_name).count
          if matches > 0
            group_name = "#{group_name} (#{matches + 1})"
          end
          [ group_name ]
        end

        def fragment_by_jid(jid, node)
          jid = JID.new(jid).bare.to_s
          clause = 'user_id=(select id from users where jid=?) and root=? and namespace=?'
          Sql::ChatFragment.where(clause, jid, node.name, node.namespace.href).first
        end

        def build_vcard(person)
          builder = Nokogiri::XML::Builder.new
          builder.vCard('xmlns' => 'vcard-temp') do |xml|
            xml.send(:"FN", person.name) if person.name
            xml.send(:"N") do |sub|
              sub.send(:"FAMILY", person.profile.last_name) if person.profile.last_name
              sub.send(:"GIVEN", person.profile.first_name) if person.profile.first_name
            end if (person.profile.last_name? || person.profile.first_name?)
            xml.send(:"URL", person.url) if person.url
            xml.send(:"PHOTO") do |sub|
              sub.send(:"EXTVAL", person.profile.image_url)
            end if person.profile.image_url
          end

          builder.to_xml :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
        end

        def get_diaspora_flags(contact)
          groups = Array.new
          ask, subscription = 'none', 'none'
          contact.aspects.each do |aspect|
            groups.push(aspect.name)
          end

          if contact.sharing && contact.receiving
            subscription = 'both'
          elsif contact.sharing && !contact.receiving
            ask = 'suscribe'
            subscription = 'from'
          elsif !contact.sharing && contact.receiving
            subscription = 'to'
          else
            ask = 'suscribe'
          end
          return ask, subscription, groups
        end
    end
  end
end
