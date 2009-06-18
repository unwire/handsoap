# -*- coding: utf-8 -*-
require 'rubygems'
require 'test/unit'
$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require 'handsoap/parser.rb'

def var_dump(val)
  puts val.to_yaml.gsub(/ !ruby\/object:.+$/, '')
end

# Amazon is rpc + literal and is self-contained
# http://soap.amazon.com/schemas2/AmazonWebServices.wsdl
class TestOfAmazonWebServicesConnection < Test::Unit::TestCase
  def test_can_connect_and_read_wsdl
    wsdl = Handsoap::Parser::Wsdl.read('http://soap.amazon.com/schemas2/AmazonWebServices.wsdl')
    assert_kind_of Handsoap::Parser::Interface, wsdl.interfaces.first
  end
end

class TestOfAmazonWebServices < Test::Unit::TestCase
  def get_wsdl
    unless @wsdl
      @wsdl = Handsoap::Parser::Wsdl.read('http://soap.amazon.com/schemas2/AmazonWebServices.wsdl')
    end
    return @wsdl
  end
  def test_can_parse_services
    wsdl = get_wsdl
    services = wsdl.endpoints
    assert_kind_of Array, services
    assert_kind_of Handsoap::Parser::Endpoint, services.first
    assert_equal 'AmazonSearchPort', services.first.name
    assert_equal 'typens:AmazonSearchBinding', services.first.binding
  end
  def test_can_parse_port_types
    wsdl = get_wsdl
    port_types = wsdl.interfaces
    assert_kind_of Array, port_types
    assert_kind_of Handsoap::Parser::Interface, port_types.first
    assert_equal 'AmazonSearchPort', port_types.first.name
    assert_kind_of Array, port_types.first.operations
    assert_equal 'KeywordSearchRequest', port_types.first.operations.first.name
  end
  def test_can_parse_bindings
    wsdl = get_wsdl
    bindings = wsdl.bindings
    assert_kind_of Array, bindings
    assert_equal 'AmazonSearchBinding', bindings.first.name
    assert_kind_of Array, bindings.first.actions
    assert_equal 'KeywordSearchRequest', bindings.first.actions.first.name
  end
end

# Thomas-Bayer is rpc + document and has external type definitions
# http://www.thomas-bayer.com/names-service/soap?wsdl
class TestOfThomasBayerNameServiceConnection < Test::Unit::TestCase
  def test_can_connect_and_read_wsdl
    wsdl = Handsoap::Parser::Wsdl.read('http://www.thomas-bayer.com/names-service/soap?wsdl')
    assert_kind_of Handsoap::Parser::Interface, wsdl.interfaces.first
  end
end

class TestOfThomasBayerNameService < Test::Unit::TestCase
  def get_wsdl
    unless @wsdl
      @wsdl = Handsoap::Parser::Wsdl.read('http://www.thomas-bayer.com/names-service/soap?wsdl')
    end
    return @wsdl
  end
  def test_can_parse_services
    wsdl = get_wsdl
    services = wsdl.endpoints
    assert_kind_of Array, services
    assert_kind_of Handsoap::Parser::Endpoint, services.first
    assert_equal 'NamesServicePort', services.first.name
    assert_equal 'tns:NamesServicePortBinding', services.first.binding
  end
  def test_can_parse_port_types
    wsdl = get_wsdl
    port_types = wsdl.interfaces
    assert_kind_of Array, port_types
    assert_kind_of Handsoap::Parser::Interface, port_types.first
    assert_equal 'NamesService', port_types.first.name
    assert_kind_of Array, port_types.first.operations
    assert_equal 'getCountries', port_types.first.operations.first.name
  end
  def test_can_parse_bindings
    wsdl = get_wsdl
    bindings = wsdl.bindings
    assert_kind_of Array, bindings
    assert_equal 'NamesServicePortBinding', bindings.first.name
    assert_kind_of Array, bindings.first.actions
    assert_equal 'getCountries', bindings.first.actions.first.name
  end
end
