# encoding: UTF-8

module Vines
  class Stream
    class Client
      class BindRestart < State
        def initialize(stream, success=Bind)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features') do |el|
            # Session support is deprecated, but like we do it for Adium
            # in the iq-session-stanza we have to serve the feature for Xabber.
            # Otherwise it will disconnect after authentication!
            el << doc.create_element('session', 'xmlns' => NAMESPACES[:session]) do |session|
              session << doc.create_element('optional')
            end
            el << doc.create_element('bind', 'xmlns' => NAMESPACES[:bind])
          end
          stream.write(features)
          advance
        end
      end
    end
  end
end
