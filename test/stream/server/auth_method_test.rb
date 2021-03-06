# encoding: UTF-8

require "test_helper"

class OperatorWrapper
  def <<(stream)
    [stream]
  end
end

describe Vines::Stream::Server::AuthMethod do
  before do
    @result = {from: "hostA.org", to: "hostB.org", token: "1234"}
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::AuthMethod.new(@stream)
  end

  def test_invalid_element
    EM.run {
      node = node("<message/>")
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_tls_element
    EM.run {
      node = node(%(<message xmlns="#{Vines::NAMESPACES[:tls]}"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_dialback_element
    EM.run {
      node = node(%(<message xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_tls_namespace
    EM.run {
      node = node("<starttls/>")
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_no_dialback_payload
    EM.run {
      node = node("<db:result/>")
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_invalid_tls_namespace
    EM.run {
      node = node(%(<starttls xmlns="#{Vines::NAMESPACES[:legacy_dialback]}"/>))
      assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
      EM.stop
    }
  end

  def test_missing_tls_certificate
    EM.run {
      @stream.expect(:encrypt?, false)
      @stream.expect(:close_connection_after_writing, nil)
      failure = %(<failure xmlns="#{Vines::NAMESPACES[:tls]}"/>)
      node = node(%(<starttls xmlns="#{Vines::NAMESPACES[:tls]}"/>))
      @stream.expect(:write, nil, [failure])
      @stream.expect(:write, nil, ["</stream:stream>"])
      @state.node(node)
      assert @stream.verify
      EM.stop
    }
  end

  def test_valid_tls
    EM.run {
      @stream.expect(:encrypt?, true)
      @stream.expect(:encrypt, nil)
      @stream.expect(:reset, nil)
      @stream.expect(:advance, nil, [Vines::Stream::Server::AuthRestart.new(@stream)])
      success = %(<proceed xmlns="#{Vines::NAMESPACES[:tls]}"/>)
      node = node(%(<starttls xmlns="#{Vines::NAMESPACES[:tls]}"/>))
      @stream.expect(:write, nil, [success])
      @state.node(node)
      assert @stream.verify
      EM.stop
    }
  end

  def test_valid_dialback
    EM.run {
      @stream.expect(:config, Vines::Config)
      @stream.expect(:router, OperatorWrapper.new)
      @stream.expect(:close_connection_after_writing, nil)
      node = node(
        %(<db:result xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" ) +
        %(from="#{@result[:from]}" to="#{@result[:to]}">#{@result[:token]}</db:result>)
      )
      @stream.expect(:authoritative_dialback, nil, [node])
      assert_nothing_raised {
        @state.node(node)
      }.must_equal(true)
      EM.stop
    }
  end

  private

  def assert_nothing_raised
    yield
      true
  rescue
    $!
  end

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
