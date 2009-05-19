# -*- coding: utf-8 -*-
require 'rubygems'
$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap.rb"
require "handsoap/parser.rb"
require "handsoap/compiler.rb"

def var_dump(val)
  puts val.to_yaml
end

require 'test/unit'

class TestOfCompiler < Test::Unit::TestCase
#   def test_generate_builder_from_complex_type
#     ns = {'xmlns:x' => 'void://'}
#     elements = [
#                 Handsoap::Parser::Element.new(
#                                               Handsoap::Parser::QName.new('coolness', ns),
#                                               Handsoap::Parser::QName.new('Coolability', ns),
#                                               nil,
#                                               nil,
#                                               nil,
#                                               nil)]
#     name = Handsoap::Parser::QName.new('x:Thing', ns)
#     attributes = []
#     attribute_groups = []
#     element_structure = Handsoap::Parser::ElementStructureAll.new(elements)
#     complex_type = Handsoap::Parser::ComplexType.new(name, nil, :complex, nil, attributes, attribute_groups, element_structure)
#     compiler = Handsoap::Compiler.new(nil, nil, nil)
#     puts compiler.compile_builder(complex_type)
#   end

  def test_can_parse_weather_summary_service
    spider = Handsoap::Parser::XsdSpider.new("#{File.dirname(__FILE__)}/WeatherSummary.wsdl")
    spider.process!
    wsdl = Handsoap::Parser::WSDL.new(spider)
    compiler = Handsoap::Compiler.new(wsdl, 'WeatherSummary', 'weather_summary')
    binding = wsdl.bindings['WeatherSummary']
    # puts compiler.compile(binding)
  end

  def test_can_parse_mooshup_service
    spider = Handsoap::Parser::XsdSpider.new("https://mooshup.com/services/system/version?wsdl")
    spider.process!
    wsdl = Handsoap::Parser::WSDL.new(spider)
    compiler = Handsoap::Compiler.new(wsdl, 'Mooshup', 'mooshup')
    binding = wsdl.bindings['system-version-SOAP12Binding']
    puts compiler.compile(binding)
  end

end
