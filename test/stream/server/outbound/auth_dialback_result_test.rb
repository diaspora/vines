# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Server::Outbound::AuthDialbackResult do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::AuthDialbackResult.new(@stream)
  end

  def test_invalid_stanza
    node = node('<message/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_invalid_result
    node = node(%Q{<db:result xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="remote.host" to="local.host" type="invalid"/>})
    @stream.expect(:close_connection, nil)
    @state.node(node)
    assert @stream.verify
  end

  def test_valid_result
    node = node(%Q{<db:result xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="remote.host" to="local.host" type="valid"/>})
    @stream.expect(:advance, nil, [Vines::Stream::Server::Ready])
    @stream.expect(:notify_connected, nil)
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
