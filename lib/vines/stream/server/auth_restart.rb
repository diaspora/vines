# encoding: UTF-8

module Vines
  class Stream
    class Server
      class AuthRestart < State
        def initialize(stream, success=Auth)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features')
          if stream.dialback_retry?
            if stream.vhost.force_s2s_encryption?
              stream.close_connection
              return
            end
            @success = AuthMethod
            features << doc.create_element('dialback') do |db|
              db.default_namespace = NAMESPACES[:dialback]
            end
          else
            features << doc.create_element('mechanisms') do |parent|
              parent.default_namespace = NAMESPACES[:sasl]
              stream.authentication_mechanisms.each do |name|
                parent << doc.create_element('mechanism', name)
              end
            end
          end
          stream.write(features)
          advance
        end
      end
    end
  end
end
