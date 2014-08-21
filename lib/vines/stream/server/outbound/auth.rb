# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Auth < State
          def initialize(stream, success=AuthExternalResult)
            super
          end

          def node(node)
            if external?(node)
              external!
            elsif dialback?(node)
              initiate_dialback!
            else
              raise StreamErrors::NotAuthorized
            end
          end

          private

          def external?(node)
            external = node.xpath("ns:mechanisms/ns:mechanism[text()='EXTERNAL']", 'ns' => NAMESPACES[:sasl]).any?
             features?(node) && external
          end

          def dialback?(node)
            dialback = node.xpath('ns:dialback', 'ns' => NAMESPACES[:dialback]).any?
            features?(node) && dialback
          end

          def features?(node)
            node.name == 'features' && namespace(node) == NAMESPACES[:stream]
          end

          def external!
            authzid = Base64.strict_encode64(stream.domain)
            stream.write(%Q{<auth xmlns="#{NAMESPACES[:sasl]}" mechanism="EXTERNAL">#{authzid}</auth>})
            advance
          end

          def initiate_dialback!
            secret = Kit.auth_token
            dialback_key = Kit.dialback_key(secret, stream.remote_domain, stream.domain, stream.id)

            stream.write(%Q(<db:result from="#{stream.domain}" to="#{stream.remote_domain}">#{dialback_key}</db:result>))

            @success = AuthDialbackResult
            advance
            stream.router << stream # We need to be discoverable for the dialback connection
                                    # Had to turn router connection collection into a set and make
                                    # API public. Alternatives?
            stream.state.dialback_secret = secret
          end
        end
      end
    end
  end
end
