# encoding: UTF-8

require "test_helper"

describe Vines::Stream::Server::Outbound::AuthRestart do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::AuthRestart.new(@stream)
  end

  def test_missing_namespace
    EM.run {
      node = node("<stream:stream/>")
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      assert @stream.verify
      EM.stop
    }
  end

  def test_invalid_namespace
    EM.run {
      node = node(%(<stream:stream xmlns="#{Vines::NAMESPACES[:stream]}"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_valid_stream
    EM.run {
      node = node(
        %(<stream:stream xmlns="jabber:client" xmlns:stream="#{Vines::NAMESPACES[:stream]}" ) +
        %(xml:lang="en" id="1234" from="host.com" version="1.0">)
      )
      @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::AuthExternal])
      @stream.expect(:dialback_retry?, false)
      @state.node(node)
      assert @stream.verify
      EM.stop
    }
  end

  def test_valid_stream_restart
    EM.run {
      node = node(
        %(<stream:stream xmlns="jabber:client" xmlns:stream="#{Vines::NAMESPACES[:stream]}" ) +
        %(xml:lang="en" id="1234" from="host.com" version="1.0">)
      )
      @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::Auth])
      @stream.expect(:outbound_tls_required?, false)
      @stream.expect(:dialback_retry?, true)
      @state.node(node)
      assert @stream.verify
      EM.stop
    }
  end

  def test_valid_stream_required_tls
    EM.run {
      node = node(
        %(<stream:stream xmlns="jabber:client" xmlns:stream="#{Vines::NAMESPACES[:stream]}") +
        %( xml:lang="en" id="1234" from="host.com" version="1.0">)
      )
      @stream.expect(:close_connection, nil)
      @stream.expect(:outbound_tls_required?, true)
      @stream.expect(:dialback_retry?, true)
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
