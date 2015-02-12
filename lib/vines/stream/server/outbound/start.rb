# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Start < State
          def initialize(stream, success=Auth)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless stream?(node)
            if stream.dialback_verify?
              @success = Authoritative
              stream.callback!
            end
            advance
          end
        end
      end
    end
  end
end
