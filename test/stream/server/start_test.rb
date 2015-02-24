# encoding: UTF-8

require 'test_helper'

class VhostWrapper
  def initialize(force = false)
    @force_s2s_encryption = force
  end
  def force_s2s_encryption?
    @force_s2s_encryption
  end
end

describe Vines::Stream::Server::AuthMethod do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Start.new(@stream)
  end

  def test_missing_namespace
    node = node('<stream:stream/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_namespace
    node = node(%Q{<stream:stream xmlns="#{Vines::NAMESPACES[:stream]}"/>})
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_valid_stream_tls_required
    node = node(%Q{<stream:stream xmlns="jabber:client" xmlns:stream="#{Vines::NAMESPACES[:stream]}" to="host.com" version="1.0"/>})
    features = node(%Q{<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}"><starttls xmlns="#{Vines::NAMESPACES[:tls]}"/><dialback xmlns="#{Vines::NAMESPACES[:dialback]}"/></stream:features>})
    @stream.expect(:start, nil, [node])
    @stream.expect(:vhost, VhostWrapper.new(false))
    @stream.expect(:advance, nil, [Vines::Stream::Server::AuthMethod])
    @stream.expect(:dialback_retry?, false)
    @stream.expect(:write, nil, [features])
    @state.node(node)
    assert @stream.verify
  end

  def test_valid_stream_with_dialback_flag
    node = node(%Q{<stream:stream xmlns="jabber:client" xmlns:stream="#{Vines::NAMESPACES[:stream]}" to="host.com" version="1.0"/>})
    features = node(%Q{<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}"><dialback xmlns="#{Vines::NAMESPACES[:dialback]}"/></stream:features>})
    @stream.expect(:start, nil, [node])
    @stream.expect(:advance, nil, [Vines::Stream::Server::AuthMethod])
    @stream.expect(:dialback_retry?, true)
    @stream.expect(:write, nil, [features])
    @state.node(node)
    assert @stream.verify
  end

  def test_valid_stream
    node = node(%Q{<stream:stream xmlns="jabber:client" xmlns:stream="#{Vines::NAMESPACES[:stream]}" to="host.com" version="1.0"/>})
    features = node(%Q{<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}"><starttls xmlns="#{Vines::NAMESPACES[:tls]}"><required/></starttls><dialback xmlns="#{Vines::NAMESPACES[:dialback]}"/></stream:features>})
    @stream.expect(:start, nil, [node])
    @stream.expect(:vhost, VhostWrapper.new(true))
    @stream.expect(:advance, nil, [Vines::Stream::Server::AuthMethod])
    @stream.expect(:dialback_retry?, false)
    @stream.expect(:write, nil, [features])
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
