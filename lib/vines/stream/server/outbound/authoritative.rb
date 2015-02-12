# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Authoritative < State
          VALID, INVALID, ERROR, TYPE = %w[valid invalid error type]
          VERIFY, ID, FROM, TO = %w[verify id from to].map {|s| s.freeze }

          def initialize(stream, success=nil)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless authoritative?(node)
            case node[TYPE]
            when INVALID
              @inbound.write(StanzaErrors::Forbidden.new(self, 'auth').to_xml)
              @inbound.close_connection_after_writing
            when VALID
              @inbound.write("<db:result from='#{node[TO]}' to='#{node[FROM]}' type='#{node[TYPE]}'/>")
              @inbound.advance(Server::Ready.new(@inbound))
              @inbound.notify_connected
            else
              @inbound.write("<db:result from='#{node[TO]}' to='#{node[FROM]}' type='#{ERROR}'>" +
                             "<error type='cancel'><item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>" +
                             "</error></db:result>")
              @inbound.close_connection_after_writing
            end
            stream.close_connection
          end

          private

          def authoritative?(node)
            @inbound = stream.router.stream_by_id(node[ID])
            node.name == VERIFY && !@inbound.nil?
          end
        end
      end
    end
  end
end
