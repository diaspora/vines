# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Auth < Client::Auth
        RESULT = "result".freeze

        def initialize(stream, success=FinalRestart)
          super
        end

        def node(node)
          if dialback_result?(node)
            # open a new connection and verify the dialback key
            stream.authoritative_dialback(node)
          else
            super
          end
        end

        private

        def dialback_result?(node)
          node.name == RESULT && namespace(node) == NAMESPACES[:legacy_dialback]
        end
      end
    end
  end
end
