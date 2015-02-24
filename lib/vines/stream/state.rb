# encoding: UTF-8

module Vines
  class Stream

    # The base class of Stream state machines. States know how to process XML
    # nodes and advance to their next valid state or fail the stream.
    class State
      include Nokogiri::XML
      include Vines::Log
      include Vines::Node

      attr_accessor :stream

      def initialize(stream, success=nil)
        @stream, @success = stream, success
      end

      def node(node)
        raise 'subclass must implement'
      end

      def ==(state)
        self.class == state.class
      end

      def eql?(state)
        state.is_a?(State) && self == state
      end

      def hash
        self.class.hash
      end

      private

      def advance
        stream.advance(@success.new(stream))
      end

      def to_stanza(node)
        super(node, stream)
      end
    end
  end
end
