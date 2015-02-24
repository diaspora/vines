# encoding: UTF-8

require 'test_helper'

class RouterWrapper
  def initialize(stream); @stream = stream; end
  def stream_by_id(id); @stream; end
end

describe Vines::Stream::Server::Outbound::Authoritative do
  before do
    @stream = MiniTest::Mock.new
    @router = RouterWrapper.new(@stream)
    @state = Vines::Stream::Server::Outbound::Authoritative.new(@stream)
  end

  def test_invalid_stanza
    node = node('<message/>')
    @stream.expect(:router, @router)
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_invalid_token
    node = node('<db:verify/>')
    router = RouterWrapper.new(nil)
    @stream.expect(:router, router)
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_valid_verification
    node = node(%Q{<db:verify xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="remote.host" to="local.host" id="1234" type="valid"/>})
    result = "<db:result xmlns:db='#{Vines::NAMESPACES[:legacy_dialback]}' from='#{node[:to]}' to='#{node[:from]}' type='#{node[:type]}'/>"
    @stream.expect(:router, @router)
    # NOTE this tests the 'inbound' stream var
    @stream.expect(:write, nil, [result])
    @stream.expect(:advance, nil, [Vines::Stream::Server::Ready])
    @stream.expect(:notify_connected, nil)
    # end
    @stream.expect(:nil?, false)
    @stream.expect(:close_connection, nil)
    @state.node(node)
    assert @stream.verify
  end

  def test_invalid_verification
    node = node(%Q{<db:verify xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="remote.host" to="local.host" id="1234" type="invalid"/>})
    result = "<db:result xmlns:db='#{Vines::NAMESPACES[:legacy_dialback]}' from='#{node[:to]}' to='#{node[:from]}' type='#{node[:type]}'/>"
    @stream.expect(:router, @router)
    # NOTE this tests the 'inbound' stream var
    @stream.expect(:close_connection_after_writing, nil)
    @stream.expect(:write, nil, [result])
    # end
    @stream.expect(:nil?, false)
    @stream.expect(:close_connection, nil)
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
