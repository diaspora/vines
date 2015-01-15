# encoding: UTF-8

module Vines
  class Storage
    include Vines::Log

    @@nicks = {}

    # Register a nickname that can be used in the config file to specify this
    # storage implementation.
    #
    # name - The String name for this storage backend.
    #
    # Returns nothing.
    def self.register(name)
      @@nicks[name.to_sym] = self
    end

    def self.from_name(name, &block)
      klass = @@nicks[name.to_sym]
      raise "#{name} storage class not found" unless klass
      klass.new(&block)
    end

    # Wrap a blocking IO method in a new method that pushes the original method
    # onto EventMachine's thread pool using EM#defer. Storage classes implemented
    # with blocking IO don't need to worry about threading or blocking the
    # EventMachine reactor thread if they wrap their methods with this one.
    #
    # Examples
    #
    #   def find_user(jid)
    #     some_blocking_lookup(jid)
    #   end
    #   defer :find_user
    #
    # Storage classes that use asynchronous IO (through an EventMachine
    # enabled library like em-http-request or em-redis) don't need any special
    # consideration and must not use this method.
    #
    # Returns nothing.
    def self.defer(method)
      old = instance_method(method)
      define_method method do |*args|
        fiber = Fiber.current
        op = operation { old.bind(self).call(*args) }
        cb = proc {|result| fiber.resume(result) }
        EM.defer(op, cb)
        Fiber.yield
      end
    end

    # Wrap a method with Fiber yield and resume logic. The method must yield
    # its result to a block. This makes it easier to write asynchronous
    # implementations of `authenticate`, `find_user`, and `save_user` that
    # block and return a result rather than yielding.
    #
    # Examples
    #
    #   def find_user(jid)
    #     http = EM::HttpRequest.new(url).get
    #     http.callback { yield build_user_from_http_response(http) }
    #   end
    #   fiber :find_user
    #
    # Because `find_user` has been wrapped in Fiber logic, we can call it
    # synchronously even though it uses asynchronous EventMachine calls.
    #
    #   user = storage.find_user('alice@wonderland.lit')
    #   puts user.nil?
    #
    # Returns nothing.
    def self.fiber(method)
      old = instance_method(method)
      define_method method do |*args|
        fiber, yielding = Fiber.current, true
        old.bind(self).call(*args) do |user|
          fiber.resume(user) rescue yielding = false
        end
        Fiber.yield if yielding
      end
    end

    # Validate the username and password pair.
    #
    # username - The String login JID to verify.
    # password - The String password the user presented to the server.
    #
    # Examples
    #
    #   user = storage.authenticate('alice@wonderland.lit', 'secr3t')
    #   puts user.nil?
    #
    # This default implementation validates the password against a bcrypt hash
    # of the password stored in the database. Sub-classes not using bcrypt
    # passwords must override this method.
    #
    # Returns a Vines::User object on success, nil on failure.
    def authenticate(username, password)
      user = find_user(username)
      hash = BCrypt::Password.new(user.password) rescue nil
      (hash && hash == password) ? user : nil
    end

    # Find the user in the storage database by their unique JID.
    #
    # jid - The String or JID of the user, possibly nil. This may be either a
    #       bare JID or full JID. Implementations of this method must convert
    #       the JID to a bare JID before searching for the user in the database.
    #
    # Examples
    #
    #   # Bare JID lookup.
    #   user = storage.find_user('alice@wonderland.lit')
    #   puts user.nil?
    #
    #   # Full JID lookup.
    #   user = storage.find_user('alice@wonderland.lit/tea')
    #   puts user.nil?
    #
    # Returns the User identified by the JID, nil if not found.
    def find_user(jid)
      raise 'subclass must implement'
    end

    # Persist the user to the database, and return when the save is complete.
    #
    # user - The User to persist.
    #
    # Examples
    #
    #   alice = Vines::User.new(jid: 'alice@wonderland.lit')
    #   storage.save_user(alice)
    #   puts 'saved'
    #
    # Returns nothing.
    def save_user(user)
      raise 'subclass must implement'
    end

    # Find the user's vcard by their unique JID.
    #
    # jid - The String or JID of the user, possibly nil. This may be either a
    #       bare JID or full JID. Implementations of this method must convert
    #       the JID to a bare JID before searching for the vcard in the database.
    #
    # Examples
    #
    #   card = storage.find_vcard('alice@wonderland.lit')
    #   puts card.nil?
    #
    # Returns the vcard's Nokogiri::XML::Node, nil if not found.
    def find_vcard(jid)
      raise 'subclass must implement'
    end

    # Save the vcard to the database, and return when the save is complete.
    #
    # jid  - The String or JID of the user, possibly nil. This may be either a
    #        bare JID or full JID. Implementations of this method must convert
    #        the JID to a bare JID before saving the vcard.
    # card - The vcard's Nokogiri::XML::Node.
    #
    # Examples
    #
    #   card = Nokogiri::XML('<vCard>...</vCard>').root
    #   storage.save_vcard('alice@wonderland.lit', card)
    #   puts 'saved'
    #
    # Returns nothing.
    def save_vcard(jid, card)
      raise 'subclass must implement'
    end

    # Find the private XML fragment previously stored by the user. Private
    # XML storage uniquely identifies fragments by JID, root element name,
    # and root element namespace.
    #
    # jid  - The String or JID of the user, possibly nil. This may be either a
    #        bare JID or full JID. Implementations of this method must convert
    #        the JID to a bare JID before searching for the fragment in the database.
    # node - The XML::Node that uniquely identifies the fragment by element
    #        name and namespace.
    #
    # Examples
    #
    #   root = Nokogiri::XML('<custom xmlns="urn:custom:ns"/>').root
    #   fragment = storage.find_fragment('alice@wonderland.lit', root)
    #   puts fragment.nil?
    #
    # Returns the fragment's Nokogiri::XML::Node or nil if not found.
    def find_fragment(jid, node)
      raise 'subclass must implement'
    end

    # Save the XML fragment to the database, and return when the save is complete.
    #
    # jid      - The String or JID of the user, possibly nil. This may be
    #            either a bare JID or full JID. Implementations of this method
    #            must convert the JID to a bare JID before searching for the
    #            fragment.
    # fragment - The XML::Node to save.
    #
    # Examples
    #
    #   fragment = Nokogiri::XML('<custom xmlns="urn:custom:ns">some data</custom>').root
    #   storage.save_fragment('alice@wonderland.lit', fragment)
    #   puts 'saved'
    #
    # Returns nothing.
    def save_fragment(jid, fragment)
      raise 'subclass must implement'
    end

    # Check whether offline messages are available for the user
    # jid      - The String or JID of the user, possibly nil. This may be
    #            either a bare JID or full JID. Implementations of this method
    #            must convert the JID to a bare JID before searching for
    #            offline messages.
    #
    # Returns hash
    def find_messages(jid)
      raise 'subclass must implement'
    end

    # Save the offline message to the database, and return when the save is complete.
    #
    # from      - The String or JID of the user.
    # to        - The String or JID of the user.
    # message   - The message you want to store.
    #
    # Returns nothing.
    def save_message(from, to, message)
      raise 'subclass must implement'
    end

    # Delete a offline message from database.
    #
    # id       - The identifier of the offline message
    #
    # Returns nothing.
    def destroy_message(id)
      raise 'subclass must implement'
    end

    # Retrieve the avatar url by jid.
    #
    # jid      - The String or JID of the user.
    #
    # Returns string
    def find_avatar_by_jid(jid)
      raise 'subclass must implement'
    end

    private

    # Determine if any of the arguments are nil or empty strings.
    #
    # Examples
    #
    #   username, password = 'alice@wonderland.lit', ''
    #   empty?(username, password) #=> true
    #
    # Returns true if any of the arguments are nil or empty strings.
    def empty?(*args)
      args.flatten.any? {|arg| (arg || '').strip.empty? }
    end

    # Create a proc suitable for running on the EM.defer thread pool, that
    # traps and logs any errors thrown by the provided block.
    #
    # block - The block to wrap in error handling.
    #
    # Examples
    #
    #   op = operation { do_something_on_thread_pool() }
    #   EM.defer(op)
    #
    # Returns a Proc.
    def operation
      proc do
        begin
          yield
        rescue => e
          log.error("Thread pool operation failed: #{e.message}")
          nil
        end
      end
    end
  end
end
