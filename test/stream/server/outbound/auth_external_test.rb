# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Server::Outbound::AuthExternal do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::AuthExternal.new(@stream)
  end

  def test_invalid_element
    EM.run {
      node = node('<message/>')
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_sasl_element
    EM.run {
      node = node(%Q{<message xmlns="#{Vines::NAMESPACES[:sasl]}"/>})
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_namespace
    EM.run {
      node = node('<stream:features/>')
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_namespace
    EM.run {
      node = node('<stream:features xmlns="bogus"/>')
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanisms
    EM.run {
      node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams"/>})
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanisms_namespace
    EM.run {
      node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams"><mechanisms/></stream:features>})
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanism
    EM.run {
      mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"/>}
      node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanism_text
    EM.run {
      mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><mechanism></mechanism></mechanisms>}
      node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_mechanism_text
    EM.run {
      mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><mechanism>BOGUS</mechanism></mechanisms>}
      node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_valid_mechanism
    EM.run {
      @stream.expect(:domain, 'wonderland.lit')
      expected = %Q{<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTERNAL">d29uZGVybGFuZC5saXQ=</auth>}
      @stream.expect(:write, nil, [expected])
      @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::AuthExternalResult.new(@stream)])
      mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><mechanism>EXTERNAL</mechanism></mechanisms>}
      node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
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
