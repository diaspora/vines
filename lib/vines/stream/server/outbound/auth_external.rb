# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthExternal < State
          def initialize(stream, success=AuthExternalResult)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless external?(node)
            authzid = Base64.strict_encode64(stream.domain)
            stream.write(%Q{<auth xmlns="#{NAMESPACES[:sasl]}" mechanism="EXTERNAL">#{authzid}</auth>})
            advance
          end

          private

          def external?(node)
            external = node.xpath("ns:mechanisms/ns:mechanism[text()='EXTERNAL']", 'ns' => NAMESPACES[:sasl]).any?
            features?(node) && external
          end

          def features?(node)
            node.name == 'features' && namespace(node) == NAMESPACES[:stream]
          end
        end
      end
    end
  end
end
