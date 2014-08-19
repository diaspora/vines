# encoding: UTF-8

module Vines
  class Storage
    class Sql < Storage
      include Vines::Log

      register :sql

      class Person < ActiveRecord::Base; end
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

      class ChatContact < ActiveRecord::Base
        belongs_to :users

        serialize :groups, JSON
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
          xuser.contacts.each do |contact|
            handle = contact.person.diaspora_handle
            ask, subscription, groups = get_diaspora_flags(contact)
            user.roster << Vines::Contact.new(
              jid: handle,
              name: handle.gsub(/\@.*?$/, ''),
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
              groups: contact.groups,
              ask: contact.ask)
          end
        end if xuser
      end
      with_connection :find_user

      def authenticate(username, password)
        user = find_user(username)

        pepper = "#{password}#{Config.instance.pepper}" rescue password
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
            subscription: fresh.subscription,
            groups: fresh.groups)
        end

        # add new contacts to roster
        user.roster.select {|contact|
          unless contact.from_diaspora
            xuser.chat_contacts.build(
              user_id: xuser.id,
              jid: contact.jid.bare.to_s,
              name: contact.name,
              ask: contact.ask,
              subscription: contact.subscription,
              groups: contact.groups)
          end
        }
        xuser.save
      end
      with_connection :save_user

      def find_vcard(jid)
        # not supported yet
        nil
      end
      with_connection :find_vcard

      def save_vcard(jid, card)
        # not supported yet
      end
      with_connection :save_vcard

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

      private
        def establish_connection
          ActiveRecord::Base.logger = log # using vines logger
          ActiveRecord::Base.establish_connection(@config)
        end

        def user_by_jid(jid)
          name = JID.new(jid).node
          Sql::User.find_by_username(name)
        end

        def fragment_by_jid(jid, node)
          jid = JID.new(jid).bare.to_s
          clause = 'user_id=(select id from users where jid=?) and root=? and namespace=?'
          Sql::ChatFragment.where(clause, jid, node.name, node.namespace.href).first
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
