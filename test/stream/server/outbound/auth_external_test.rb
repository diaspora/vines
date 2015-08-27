# encoding: UTF-8

require "test_helper"

describe Vines::Stream::Server::Outbound::AuthExternal do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::AuthExternal.new(@stream)
  end

  def test_invalid_element
    EM.run {
      node = node("<message/>")
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_sasl_element
    EM.run {
      node = node(%(<message xmlns="#{Vines::NAMESPACES[:sasl]}"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_namespace
    EM.run {
      node = node("<stream:features/>")
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_namespace
    EM.run {
      node = node(%(<stream:features xmlns="bogus"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanisms
    EM.run {
      node = node(%(<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanisms_namespace
    EM.run {
      node = node(%(<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}"><mechanisms/></stream:features>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanism
    EM.run {
      mechanisms = %(<mechanisms xmlns="#{Vines::NAMESPACES[:sasl]}"/>)
      node = node(%(<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}">#{mechanisms}</stream:features>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_mechanism_text
    EM.run {
      mechanisms = %(<mechanisms xmlns="#{Vines::NAMESPACES[:sasl]}"><mechanism></mechanism></mechanisms>)
      node = node(%(<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}">#{mechanisms}</stream:features>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_mechanism_text
    EM.run {
      mechanisms = %(<mechanisms xmlns="#{Vines::NAMESPACES[:sasl]}"><mechanism>BOGUS</mechanism></mechanisms>)
      node = node(%(<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}">#{mechanisms}</stream:features>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_valid_mechanism
    EM.run {
      @stream.expect(:domain, "wonderland.lit")
      expected = %(<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="EXTERNAL">d29uZGVybGFuZC5saXQ=</auth>)
      @stream.expect(:write, nil, [expected])
      @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::AuthExternalResult.new(@stream)])
      mechanisms = %(<mechanisms xmlns="#{Vines::NAMESPACES[:sasl]}"><mechanism>EXTERNAL</mechanism></mechanisms>)
      node = node(%(<stream:features xmlns:stream="#{Vines::NAMESPACES[:stream]}">#{mechanisms}</stream:features>))
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
