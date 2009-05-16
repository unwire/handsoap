# -*- coding: utf-8 -*-
require 'rubygems'
require '../lib/handsoap/parser.rb'

def var_dump(val)
  puts val.to_yaml.gsub(/ !ruby\/object:.+$/, '')
end

require 'test/unit'

# Amazon is rpc + literal and is self-contained
# http://soap.amazon.com/schemas2/AmazonWebServices.wsdl
class TestOfAmazonWebServicesConnection < Test::Unit::TestCase
  def test_can_connect_and_read_wsdl
    spider = Handsoap::Parser::XsdSpider.new('http://soap.amazon.com/schemas2/AmazonWebServices.wsdl')
    spider.process!
    assert_kind_of Array, spider.results
    assert spider.results.length > 0, "Didn't read definitions"
    assert_kind_of Hash, spider.wsdl
    assert_kind_of Nokogiri::XML::Document, spider.wsdl[:document]
    # var_dump spider.wsdl[:document].namespaces
  end
end

class TestOfAmazonWebServices < Test::Unit::TestCase
  def get_spider
    unless @spider
      @spider = Handsoap::Parser::XsdSpider.new('http://soap.amazon.com/schemas2/AmazonWebServices.wsdl')
      @spider.process!
    end
    return @spider
  end
  def test_can_parse_services
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    services = wsdl.services
    assert_kind_of Hash, services
    assert_equal 'AmazonSearchService', services.keys[0]
    amazon_search_service = services['AmazonSearchService']
    assert_kind_of Hash, amazon_search_service
    assert_equal 'AmazonSearchPort', amazon_search_service.keys[0]
  end
  def test_can_parse_port_types
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    port_types = wsdl.port_types
    assert_kind_of Hash, port_types
    assert_equal 'AmazonSearchPort', port_types.keys[0]
    amazon_search_port = port_types['AmazonSearchPort']
    assert_kind_of Hash, amazon_search_port
    assert_equal 'UpcSearchRequest', amazon_search_port.keys[0]
  end
  def test_can_parse_messages
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    messages = wsdl.messages
    assert_kind_of Hash, messages
    assert_equal 'ShoppingCartResponse', messages.keys[0]
  end
  def test_can_parse_bindings
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    bindings = wsdl.bindings
    assert_kind_of Hash, bindings
  end
end

# Thomas-Bayer is rpc + document and has external type definitions
# http://www.thomas-bayer.com/names-service/soap?wsdl
class TestOfThomasBayerNameServiceConnection < Test::Unit::TestCase
  def test_can_connect_and_read_wsdl
    spider = Handsoap::Parser::XsdSpider.new('http://www.thomas-bayer.com/names-service/soap?wsdl')
    spider.process!
    assert_kind_of Array, spider.results
    assert spider.results.length > 0, "Didn't read definitions"
    assert_kind_of Hash, spider.wsdl
    assert_kind_of Nokogiri::XML::Document, spider.wsdl[:document]
  end
end

class TestOfThomasBayerNameService < Test::Unit::TestCase
  def get_spider
    unless @spider
      @spider = Handsoap::Parser::XsdSpider.new('http://www.thomas-bayer.com/names-service/soap?wsdl')
      @spider.process!
    end
    return @spider
  end
  def test_can_parse_services
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    services = wsdl.services
    assert_kind_of Hash, services
    assert_equal 'NamesServiceService', services.keys[0]
    name_service = services['NamesServiceService']
    assert_kind_of Hash, name_service
    assert_equal 'NamesServicePort', name_service.keys[0]
  end
  def test_can_parse_port_types
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    port_types = wsdl.port_types
    assert_kind_of Hash, port_types
    assert_equal 'NamesService', port_types.keys[0]
    name_service = port_types['NamesService']
    assert_kind_of Hash, name_service
    assert_equal 'getNamesInCountry', name_service.keys[0]
  end
  def test_can_parse_messages
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    messages = wsdl.messages
    assert_kind_of Hash, messages
    assert_equal 'getNamesInCountry', messages.keys[0]
    assert_kind_of Handsoap::Parser::Part, messages['getNamesInCountry']['parameters']
    assert_equal 'getNamesInCountry', messages['getNamesInCountry']['parameters'].type.name
  end
  def test_can_parse_bindings
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    bindings = wsdl.bindings
    assert_kind_of Hash, bindings
  end
  def test_can_parse_elements
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    elements = wsdl.elements
    assert_kind_of Hash, elements
    assert_equal '{http://namesservice.thomas_bayer.com/}getNameInfo', elements.keys[0]
    assert_kind_of Handsoap::Parser::Element, elements['{http://namesservice.thomas_bayer.com/}getNameInfo']
  end
  def test_can_parse_types
    wsdl = Handsoap::Parser::WSDL.new(get_spider)
    types = wsdl.types
    assert_kind_of Hash, types
    assert_equal '{http://namesservice.thomas_bayer.com/}getNameInfo', types.keys[0]
    assert_kind_of Handsoap::Parser::ComplexType, types['{http://namesservice.thomas_bayer.com/}getNameInfo']
  end
end



# spider = Handsoap::XsdSpider.new('http://soap.amazon.com/schemas2/AmazonWebServices.wsdl')
# spider.process!
# # var_dump spider.results

# wsdl = Handsoap::WSDL.new(spider)
# var_dump wsdl.messages.keys
# # var_dump wsdl.port_types
