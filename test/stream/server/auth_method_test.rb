# encoding: UTF-8

require 'test_helper'

class OperatorWrapper
  def <<(stream)
    [stream]
  end
end

describe Vines::Stream::Server::AuthMethod do
  before do
    @result = {
      from: 'hostA.org',
      to: 'hostB.org',
      token: '1234'
    }
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::AuthMethod.new(@stream)
  end

  def test_invalid_element
    node = node('<message/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_tls_element
    node = node(%Q{<message xmlns="#{Vines::NAMESPACES[:tls]}"/>})
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_dialback_element
    node = node(%Q{<message xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}"/>})
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_tls_namespace
    node = node('<starttls/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_no_dialback_payload
    node = node('<db:result/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_tls_namespace
    node = node(%Q{<starttls xmlns="#{Vines::NAMESPACES[:legacy_dialback]}"/>})
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_tls_certificate
    @stream.expect(:encrypt?, false)
    @stream.expect(:close_connection_after_writing, nil)
    failure = %Q{<failure xmlns="#{Vines::NAMESPACES[:tls]}"/>}
    node = node(%Q{<starttls xmlns="#{Vines::NAMESPACES[:tls]}"/>})
    @stream.expect(:write, nil, [failure])
    @stream.expect(:write, nil, ['</stream:stream>'])
    @state.node(node)
    assert @stream.verify
  end

  def test_valid_tls
    @stream.expect(:encrypt?, true)
    @stream.expect(:encrypt, nil)
    @stream.expect(:reset, nil)
    @stream.expect(:advance, nil, [Vines::Stream::Server::AuthRestart.new(@stream)])
    success = %Q{<proceed xmlns="#{Vines::NAMESPACES[:tls]}"/>}
    node = node(%Q{<starttls xmlns="#{Vines::NAMESPACES[:tls]}"/>})
    @stream.expect(:write, nil, [success])
    @state.node(node)
    assert @stream.verify
  end

  def test_valid_dialback
    @stream.expect(:config, Vines::Config)
    @stream.expect(:router, OperatorWrapper.new)
    @stream.expect(:close_connection_after_writing, nil)
    node = node(%Q{
      <db:result xmlns:db="#{Vines::NAMESPACES[:legacy_dialback]}" from="#{@result[:from]}" to="#{@result[:to]}">
        #{@result[:token]}
      </db:result>
    })
    assert_nothing_raised do
      @state.node(node)
    end.must_equal(true)
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
