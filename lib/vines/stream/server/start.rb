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
          features = doc.create_element('stream:features', 'xmlns:stream' => NAMESPACES[:stream]) do |el|
            unless stream.dialback_retry?
              el << doc.create_element('starttls') do |tls|
                tls.default_namespace = NAMESPACES[:tls]
                tls << doc.create_element('required') if force_s2s_encryption?
              end
            end
            el << doc.create_element('dialback') do |db|
              db.default_namespace = NAMESPACES[:dialback]
            end
          end
          stream.write(features)
          advance
        end

        private

        def force_s2s_encryption?
          stream.vhost.force_s2s_encryption?
        end
      end
    end
  end
end
