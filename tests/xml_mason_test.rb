# -*- coding: utf-8 -*-
require 'rubygems'
$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/xml_mason'

require 'test/unit'

class TestOfXmlMason < Test::Unit::TestCase
  def test_namespaces_are_automagically_assigned_upon_usage
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.alias 'x', 'http://example.com/x'
      doc.alias 'y', 'http://example.com/y'
      doc.add 'x:body' do |b|
        b.add 'y:yonks'
      end
    end
    xml = "<?xml version='1.0' ?>\n" +
      "<x:body xmlns:x=\"http://example.com/x\">\n" +
      "  <y:yonks xmlns:y=\"http://example.com/y\" />\n" +
      "</x:body>"
    assert_equal xml, doc.to_s
  end
  def test_namespaces_are_only_declared_on_the_topmost_level
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.alias 'x', 'http://example.com/x'
      doc.add 'x:body' do |b|
        b.add 'x:yonks'
      end
    end
    xml = "<?xml version='1.0' ?>\n" +
      "<x:body xmlns:x=\"http://example.com/x\">\n" +
      "  <x:yonks />\n" +
      "</x:body>"
    assert_equal xml, doc.to_s
  end
  def test_unused_namespaces_arent_included
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.alias 'x', 'http://example.com/x'
      doc.alias 'y', 'http://example.com/y'
      doc.add 'x:body' do |b|
        b.add 'x:yonks'
      end
    end
    xml = "<?xml version='1.0' ?>\n" +
      "<x:body xmlns:x=\"http://example.com/x\">\n" +
      "  <x:yonks />\n" +
      "</x:body>"
    assert_equal xml, doc.to_s
  end
  def test_textnodes_arent_indented
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.add 'body' do |b|
        b.add 'yonks', "lorem\nipsum\ndolor\nsit amet"
      end
    end
    contents = doc.to_s.match(/<yonks>([\w\W]*)<\/yonks>/)[1]
    assert_equal "lorem\nipsum\ndolor\nsit amet", contents
  end
  def test_node_contents_is_escaped
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.add 'body' do |b|
        b.add 'yonks' do |y|
          y.set_value '<b>bold</b>'
        end
      end
    end
    contents = doc.to_s.match(/<yonks>([\w\W]*)<\/yonks>/)[1]
    assert_equal "&lt;b&gt;bold&lt;/b&gt;", contents
  end
  def test_node_contents_is_not_escaped_if_flag_raw
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.add 'body' do |b|
        b.add 'yonks' do |y|
          y.set_value '<b>bold</b>', :raw
        end
      end
    end
    contents = doc.to_s.match(/<yonks>([\w\W]*)<\/yonks>/)[1]
    assert_equal "<b>bold</b>", contents
  end
  def test_finder_can_locate_node_by_nodename
    node = nil
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.add 'body' do |b|
        b.add 'yonks', "lorem\nipsum\ndolor\nsit amet"
        b.add 'ninja' do |n|
          node = n
          n.set_value "ninja"
        end
        b.add 'ninjitsu' do |n|
          n.set_value "ninjitsu"
        end
      end
    end
    assert_equal "<ninjitsu>ninjitsu</ninjitsu>", node.document.find('ninjitsu').to_s
    assert_equal "<ninjitsu>ninjitsu</ninjitsu>", node.document.find(:ninjitsu).to_s
  end
  def test_xml_header_is_optional
    doc = Handsoap::XmlMason::Document.new do |doc|
      doc.add "foo", "Lorem Ipsum"
    end
    doc.xml_header = false
    assert_equal "<foo>Lorem Ipsum</foo>", doc.to_s
  end
end

=begin

# doc = Handsoap::XmlMason::Document.new do |doc|
#   doc.alias 'env', "http://www.w3.org/2003/05/soap-envelope"
#   doc.alias 'm', "http://travelcompany.example.org/reservation"
#   doc.alias 'n', "http://mycompany.example.com/employees"
#   doc.alias 'p', "http://travelcompany.example.org/reservation/travel"
#   doc.alias 'q', "http://travelcompany.example.org/reservation/hotels"

#   doc.add "env:Envelope" do |env|
#     env.add "Header" do |header|
#       header.add 'm:reservation' do |r|
#         r.set_attr 'env:role', "http://www.w3.org/2003/05/soap-envelope/role/next"
#         r.set_attr 'env:mustUnderstand', "true"
#         r.add 'reference', "uuid:093a2da1-q345-739r-ba5d-pqff98fe8j7d"
#         r.add 'dateAndTime', "2001-11-29T13:20:00.000-05:00"
#       end
#       header.add 'n:passenger' do |p|
#         p.set_attr 'env:role', "http://www.w3.org/2003/05/soap-envelope/role/next"
#         p.set_attr 'env:mustUnderstand', "true"
#         p.add 'name', "Åke Jógvan Øyvind"
#       end
#     end
#     env.add "Body" do |body|
#       body.add 'p:itinerary' do |i|
#         i.add 'departure' do |d|
#           d.add 'departing', "New York"
#           d.add 'arriving', "Los Angeles"
#           d.add 'departureDate', "2001-12-14"
#           d.add 'departureTime', "late afternoon"
#           d.add 'seatPreference', "aisle"
#         end
#         i.add 'return' do |r|
#           r.add 'departing', "Los Angeles"
#           r.add 'arriving', "New York"
#           r.add 'departureDate', "2001-12-20"
#           r.add 'departureTime', "mid-morning"
#           r.add 'seatPreference'
#         end
#       end
#       body.add 'q:lodging' do |l|
#         l.add 'preference', "none"
#       end
#     end
#   end
# end

# puts doc
# puts doc.find("Body")
# puts doc.find_all("departureTime")

=end
