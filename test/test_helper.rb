# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'
require 'rails/all'

# A simple hook allowing you to run a block of code after everything is done running
# In this case we want to delete the old sqlite database in case we run rake-test twice
Minitest.after_run {
  db_file = "test.db"
  File.delete(db_file) if File.exist?(db_file)
  puts "After_run hook deleted #{db_file}"
}

class MiniTest::Spec

  # Build an <iq> xml node with the given attributes. This is useful as a
  # quick way to build a node to use as expected stanza output from a
  # Stream#write call.
  #
  # options - The Hash of xml attributes to include on the iq element. Attribute
  #           values of nil or empty? are excluded from the generated element.
  #           :body - The String xml content to include in the iq element.
  #
  # Examples
  #
  #   iq(from: from, id: 42, to: to, type: 'result', body: card)
  #
  # Returns a Nokogiri::XML::Node.
  def iq(options)
    body = options.delete(:body)
    options.delete_if {|k, v| v.nil? || v.to_s.empty? }
    attrs = options.map {|k, v| "#{k}=\"#{v}\"" }.join(' ')
    node("<iq #{attrs}>#{body}</iq>")
  end

  # Parse xml into a nokogiri node. Strip excessive whitespace from the xml
  # content before parsing because it affects comparisons in MiniTest::Mock
  # expectations.
  #
  # xml - The String of xml content to parse.
  #
  # Returns a Nokogiri::XML::Node.
  def node(xml)
    xml = xml.strip.gsub(/\n|\s{2,}/, '')
    Nokogiri::XML(xml).root
  end
end

