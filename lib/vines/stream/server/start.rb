# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Start < State
        FROM = "from".freeze

        def initialize(stream, success=AuthMethod)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features') do |el|
            #el << doc.create_element('starttls') do |tls|
            #  tls.default_namespace = NAMESPACES[:tls]
            #end
            el << doc.create_element('dialback') do |db|
              db.default_namespace = NAMESPACES[:dialback]
            end
          end
          stream.write(features)
          advance
        end
      end
    end
  end
end
