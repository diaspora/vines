# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthDialbackResult < State
          RESULT, VALID, INVALID, TYPE = %w[result valid invalid type].map {|s| s.freeze }

          attr_accessor :dialback_secret

          def initialize(stream, success=Ready)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless result?(node)

            case node[TYPE]
            when VALID
              advance
              stream.notify_connected
            when INVALID
              stream.close_connection
            else
              raise StreamErrors::NotAuthorized
            end
          end

          private

          def result?(node)
            node.name == RESULT && namespace(node) == NAMESPACES[:legacy_dialback]
          end
        end
      end
    end
  end
end
