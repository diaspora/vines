# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthRestart < State
          def initialize(stream, success=AuthExternal)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless stream?(node)
            if stream.dialback_retry?
              if stream.outbound_tls_required?
                stream.close_connection
                return
              end
              @success = Auth
            end
            advance
          end
        end
      end
    end
  end
end
