# encoding: UTF-8

module Vines
  class Stream
    class Server
      class AuthMethod < State
        VERIFY, VALID_TYPE, INVALID_TYPE = %w[verify valid invalid].map {|t| t.freeze }
        STARTTLS, RESULT, FROM, TO = %w[starttls result from to].map {|s| s.freeze }
        PROCEED  = %Q{<proceed xmlns="#{NAMESPACES[:tls]}"/>}.freeze
        FAILURE  = %Q{<failure xmlns="#{NAMESPACES[:tls]}"/>}.freeze

        def initialize(stream, success=AuthRestart)
          super
        end

        def node(node)
          if dialback_verify?(node)
            id, from, to = %w[id from to].map {|a| node[a] }
            key = node.text
            outbound_stream = stream.router.stream_by_id(id)

            unless outbound_stream && outbound_stream.state.is_a?(Stream::Server::Outbound::AuthDialbackResult)
              stream.write(%Q{<db:verify from="#{to}" to=#{from} id=#{id} type="error"><error type="cancel"><item-not-found xmlns="#{NAMESPACES[:stanzas]}" /></error></db:verify>})
              return
            end

            secret = outbound_stream.state.dialback_secret
            type = Kit.dialback_key(secret, from, to, id) == key ? VALID_TYPE : INVALID_TYPE
            stream.write(%Q{<db:verify from="#{to}" to="#{from}" id="#{id}" type="#{type}" />})
            stream.close_connection_after_writing
          elsif starttls?(node)
            if stream.encrypt?
              stream.write(PROCEED)
              stream.encrypt
              stream.reset
              advance
            else
              stream.write(FAILURE)
              stream.write('</stream:stream>')
              stream.close_connection_after_writing
            end
          elsif dialback_result?(node)
            begin
              Vines::Stream::Server.start(stream.config, node[FROM], node[TO], true) do |authoritative|
                if authoritative
                  # will be closed in outbound/authoritative.rb
                  authoritative.write("<db:verify from='#{node[TO]}' id='#{stream.id}' to='#{node[FROM]}'>#{node.text}</db:verify>")
                end
              end
              # We need to be discoverable for the dialback connection
              stream.router << stream
            rescue StanzaErrors::RemoteServerNotFound => e
              stream.write("<db:result from='#{node[TO]}' to='#{node[FROM]}' " \
                           "type='error'><error type='cancel'><item-not-found " \
                           "xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/></error></db:result>")
              stream.close_connection_after_writing
            end
          else
            raise StreamErrors::NotAuthorized
          end
        end

        private

        def starttls?(node)
          node.name == STARTTLS && namespace(node) == NAMESPACES[:tls]
        end

        def dialback_verify?(node)
          node.name == VERIFY && namespace(node) == NAMESPACES[:legacy_dialback]
        end

        def dialback_result?(node)
          node.name == RESULT && namespace(node) == NAMESPACES[:legacy_dialback]
        end
      end
    end
  end
end
