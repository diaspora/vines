module Vines
  # Utility functions to work with nodes
  module Node

    STREAM = 'stream'.freeze
    BODY   = 'body'.freeze

    module_function

    # Check if node starts a new stream
    def stream?(node)
      node.name == STREAM && namespace(node) == NAMESPACES[:stream]
    end

    # Check if BOSH body
    def body?(node)
      node.name == BODY && namespace(node) == NAMESPACES[:http_bind]
    end

    # Get the namespace
    def namespace(node)
      namespace = node.namespace
      namespace && namespace.href
    end

    # Convert to stanza
    def to_stanza(node, stream)
      Stanza.from_node(node, stream)
    end
  end
end
