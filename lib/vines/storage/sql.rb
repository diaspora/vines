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

        has_many :aspect_memberships, :order => 'aspect_id ASC'
        has_many :aspects, :through => :aspect_memberships
      end

      class User < ActiveRecord::Base
        has_many :contacts

        has_one :person, :foreign_key => :owner_id
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
        raise "You configured diaspora-sql adapter without Diaspora" unless defined? AppConfig
        @config = {
          :adapter => AppConfig.adapter.to_s,
          :database => AppConfig.database.to_s,
          :host => AppConfig.host.to_s,
          :port => AppConfig.port.to_i,
          :username => AppConfig.username.to_s,
          :password => AppConfig.password.to_s
        }

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

          xuser.contacts.each do |contact|
            entry = build_roster_entry(contact)
            unless entry.nil?
              user.roster << entry
            end
          end
        end if xuser
      end
      with_connection :find_user

      def authenticate(username, password)
        user = find_user(username)

        dbhash = BCrypt::Password.new(user.password) rescue nil
        hash = BCrypt::Engine.hash_secret("#{password}#{Config.instance.pepper}", dbhash.salt) rescue nil

        userAuth = ((hash && dbhash) && hash == dbhash)
        tokenAuth = ((password && user.token) && password == user.token)
        (tokenAuth || userAuth)? user : nil
      end

      def save_user(user)
        # do nothing
      end
      with_connection :save_user

      def find_vcard(jid)
        # do nothing
        nil
      end
      with_connection :find_vcard

      def save_vcard(jid, card)
        # do nothing
      end
      with_connection :save_vcard

      def find_fragment(jid, node)
        # do nothing
        nil
      end
      with_connection :find_fragment

      def save_fragment(jid, node)
        # do nothing
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

        def build_roster_entry(contact)
          groups = Array.new
          contact.aspects.each do |aspect|
            groups.push(aspect.name)
          end

          handle = contact.person.diaspora_handle
          ask = 'none'
          subscription = 'none'
          
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

          # finally build the roster entry
          return Vines::Contact.new(
            jid: handle,
            name: handle.gsub(/\@.*?$/, ''),
            subscription: subscription,
            groups: groups,
            ask: ask
          ) || nil
        end
    end
  end
end
