# encoding: UTF-8

module Vines
  class Stanza
    class Dialback < Stanza
      VALID_TYPE, INVALID_TYPE = %w[valid invalid].map {|t| t.freeze }
      NS = NAMESPACES[:legacy_dialback]

      register "/db:verify", 'db' => NS

      def process
        id, from, to = %w[id from to].map {|a| @node[a] }
        key = @node.text
        # Maybe select by id?
        outbound_stream = router.stream_by_id(id)

        # Turn into error ?
        unless outbound_stream && outbound_stream.state.is_a?(Stream::Server::Outbound::AuthDialbackResult)
          @stream.write(%Q{<db:verify from="#{to}" to=#{from} id=#{id} type="error"><error type="cancel"><item-not-found xmlns="#{NAMESPACES[:stanzas]}" /></error></db:verify>})
          return
        end

        secret = outbound_stream.state.dialback_secret

        type = Kit.dialback_key(secret, from, to, id) == key ? VALID_TYPE : INVALID_TYPE
        @stream.write(%Q{<db:verify from="#{to}" to="#{from}" id="#{id}" type="#{type}" />})
        @stream.router.delete(@stream)
      end
    end
  end
end
