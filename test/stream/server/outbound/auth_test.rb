# encoding: UTF-8

require 'test_helper'

class OperatorWrapper
  def <<(stream)
    [stream]
  end
end

class StateWrapper
  def dialback_secret=(secret); end
end

module Vines
  module Kit
    def auth_token; "1234"; end
  end
end

describe Vines::Stream::Server::Outbound::Auth do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::Auth.new(@stream)
  end

  def test_missing_children
    skip()
    node = node('<stream:features/>')
    @stream.expect(:outbound_tls_required, nil, [false])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_invalid_children
    skip()
    node = node(%Q{<stream:features><message/></stream:features>})
    @stream.expect(:outbound_tls_required, nil, [false])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_valid_stream_features
    skip()
    node = node(%Q{<stream:features><starttls xmlns="#{Vines::NAMESPACES[:tls]}"><required/></starttls><dialback xmlns="#{Vines::NAMESPACES[:dialback]}"/></stream:features>})
    starttls = "<starttls xmlns='#{Vines::NAMESPACES[:tls]}'/>"
    @stream.expect(:outbound_tls_required, nil, [true])
    @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::TLSResult])
    @stream.expect(:write, nil, [starttls])
    @state.node(node)
    assert @stream.verify
  end

  def test_dialback_feature_only
    node = node(%Q{<features><dialback xmlns="#{Vines::NAMESPACES[:dialback]}"/></features>})
    @stream.expect(:router, OperatorWrapper.new)
    @stream.expect(:domain, "local.host")
    @stream.expect(:remote_domain, "remote.host")
    @stream.expect(:domain, "local.host")
    @stream.expect(:remote_domain, "remote.host")
    @stream.expect(:id, "1234")
    @stream.expect(:write, nil, [String])
    @stream.expect(:outbound_tls_required, nil, [false])
    @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::AuthDialbackResult])
    @stream.expect(:state, StateWrapper.new)
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
