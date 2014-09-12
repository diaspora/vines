# encoding: UTF-8

module Vines
  class Storage
    include Vines::Log

    @@nicks = {}

    # Register a nickname that can be used in the config file to specify this
    # storage implementation.
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
    # For example:
    # def find_user(jid)
    #   some_blocking_lookup(jid)
    # end
    # defer :find_user
    #
    # Storage classes that use asynchronous IO (through an EventMachine
    # enabled library like em-http-request or em-redis) don't need any special
    # consideration and must not use this method.
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
    # implementations of +authenticate+, +find_user+, and +save_user+ that
    # block and return a result rather than yielding.
    #
    # For example:
    # def find_user(jid)
    #   http = EM::HttpRequest.new(url).get
    #   http.callback { yield build_user_from_http_response(http) }
    # end
    # fiber :find_user
    #
    # Because +find_user+ has been wrapped in Fiber logic, we can call it
    # synchronously even though it uses asynchronous EventMachine calls.
    #
    # user = storage.find_user('alice@wonderland.lit')
    # puts user.nil?
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

    # Validate the username and password pair and return a +Vines::User+ object
    # on success. Return +nil+ on failure.
    #
    # For example:
    # user = storage.authenticate('alice@wonderland.lit', 'secr3t')
    # puts user.nil?
    #
    # This default implementation validates the password against a bcrypt hash
    # of the password stored in the database. Sub-classes not using bcrypt
    # passwords must override this method.
    def authenticate(username, password)
      user = find_user(username)
      hash = BCrypt::Password.new(user.password) rescue nil
      (hash && hash == password) ? user : nil
    end

    # Return the +Vines::User+ associated with the JID. Return +nil+ if the user
    # could not be found. JID may be +nil+, a +String+, or a +Vines::JID+
    # object. It may be a bare JID or a full JID. Implementations of this method
    # must convert the JID to a bare JID before searching for the user in the
    # database.
    #
    # user = storage.find_user('alice@wonderland.lit')
    # puts user.nil?
    def find_user(jid)
      raise 'subclass must implement'
    end

    # Persist the +Vines::User+ object to the database and return when the save
    # is complete.
    #
    # alice = Vines::User.new(:jid => 'alice@wonderland.lit')
    # storage.save_user(alice)
    # puts 'saved'
    def save_user(user)
      raise 'subclass must implement'
    end

    # Return the Nokogiri::XML::Node for the vcard stored for this JID. Return
    # nil if the vcard could not be found. JID may be +nil+, a +String+, or a
    # +Vines::JID+ object. It may be a bare JID or a full JID. Implementations
    # of this method must convert the JID to a bare JID before searching for the
    # vcard in the database.
    #
    # card = storage.find_vcard('alice@wonderland.lit')
    # puts card.nil?
    def find_vcard(jid)
      raise 'subclass must implement'
    end

    # Save the vcard to the database and return when the save is complete. JID
    # may be a +String+ or a +Vines::JID+ object.  It may be a bare JID or a
    # full JID. Implementations of this method must convert the JID to a bare
    # JID before saving the vcard. Card is a +Nokogiri::XML::Node+ object.
    #
    # card = Nokogiri::XML('<vCard>...</vCard>').root
    # storage.save_vcard('alice@wonderland.lit', card)
    # puts 'saved'
    def save_vcard(jid, card)
      raise 'subclass must implement'
    end

    # Return the Nokogiri::XML::Node for the XML fragment stored for this JID.
    # Return nil if the fragment could not be found. JID may be +nil+, a
    # +String+, or a +Vines::JID+ object. It may be a bare JID or a full JID.
    # Implementations of this method must convert the JID to a bare JID before
    # searching for the fragment in the database.
    #
    # Private XML storage uniquely identifies fragments by JID, root element name,
    # and root element namespace.
    #
    # root = Nokogiri::XML('<custom xmlns="urn:custom:ns"/>').root
    # fragment = storage.find_fragment('alice@wonderland.lit', root)
    # puts fragment.nil?
    def find_fragment(jid, node)
      raise 'subclass must implement'
    end

    # Save the XML fragment to the database and return when the save is complete.
    # JID may be a +String+ or a +Vines::JID+ object.  It may be a bare JID or a
    # full JID. Implementations of this method must convert the JID to a bare
    # JID before saving the fragment. Fragment is a +Nokogiri::XML::Node+ object.
    #
    # fragment = Nokogiri::XML('<custom xmlns="urn:custom:ns">some data</custom>').root
    # storage.save_fragment('alice@wonderland.lit', fragment)
    # puts 'saved'
    def save_fragment(jid, fragment)
      raise 'subclass must implement'
    end

    private

    # Return true if any of the arguments are nil or empty strings.
    # For example:
    # username, password = 'alice@wonderland.lit', ''
    # empty?(username, password) #=> true
    def empty?(*args)
      args.flatten.any? {|arg| (arg || '').strip.empty? }
    end

    # Return a +proc+ suitable for running on the +EM.defer+ thread pool that traps
    # and logs any errors thrown by the provided block.
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
