# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Server::Outbound::AuthDialbackResult do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::AuthDialbackResult.new(@stream)
  end

  def test_invalid_stanza
    EM.run {
      node = node('<message/>')
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      assert @stream.verify
      EM.stop
    }
  end

  def test_invalid_result
    EM.run {
      node = node(%Q{<db:result xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="remote.host" to="local.host" type="invalid"/>})
      @stream.expect(:close_connection, nil)
      @state.node(node)
      assert @stream.verify
      EM.stop
    }
  end

  def test_valid_result
    EM.run {
      node = node(%Q{<db:result xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="remote.host" to="local.host" type="valid"/>})
      @stream.expect(:advance, nil, [Vines::Stream::Server::Ready])
      @stream.expect(:notify_connected, nil)
      @state.node(node)
      assert @stream.verify
      EM.stop
    }
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
