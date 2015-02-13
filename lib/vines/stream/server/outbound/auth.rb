# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Auth < State
          REQUIRED = 'required'.freeze

          def initialize(stream, success=AuthDialbackResult)
            super
          end

          def node(node)
            # We have to remember tls_require for
            # closing or restarting the stream
            stream.outbound_tls_required(tls_required?(node))

            if tls?(node)
              @success = TLSResult
              stream.write("<starttls xmlns='#{NAMESPACES[:tls]}'/>")
              advance
            elsif dialback?(node)
              secret = Kit.auth_token
              dialback_key = Kit.dialback_key(secret, stream.remote_domain, stream.domain, stream.id)
              stream.write(%Q(<db:result from="#{stream.domain}" to="#{stream.remote_domain}">#{dialback_key}</db:result>))
              advance
              stream.router << stream # We need to be discoverable for the dialback connection
              stream.state.dialback_secret = secret
            else
              raise StreamErrors::NotAuthorized
            end
          end

          private

          def tls_required?(node)
            child = node.xpath('ns:starttls', 'ns' => NAMESPACES[:tls]).children.first
            !child.nil? && child.name == REQUIRED
          end

          def dialback?(node)
            dialback = node.xpath('ns:dialback', 'ns' => NAMESPACES[:dialback]).any?
            features?(node) && dialback
          end

          def tls?(node)
            tls = node.xpath('ns:starttls', 'ns' => NAMESPACES[:tls]).any?
            features?(node) && tls
          end

          def features?(node)
            node.name == 'features' && namespace(node) == NAMESPACES[:stream]
          end
        end
      end
    end
  end
end
