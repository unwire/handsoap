# -*- coding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'rubygems'
require 'handsoap'
require 'soap/wsdlDriver'
require 'soap/header/simplehandler'
require 'benchmark'

#
# Start the mockservice with:
#   sh ~/path/to/soapui-2.5.1/bin/mockservicerunner.sh -p 8088 tests/GoogleSearch-soapui-project.xml
#
# Run the benchmark with (100 tries):
#   ruby tests/benchmark_integration_test.rb 100
#

# handsoap mappings:

class TestService < Handsoap::Service
  endpoint :uri => 'http://127.0.0.1:8088/mockGoogleSearchBinding', :version => 1
  map_method :do_spelling_suggestion => "urn:doSpellingSuggestion"
  on_create_document do |doc|
    doc.alias 'urn', "urn:GoogleSearch"
    doc.alias 'xsi', "http://www.w3.org/2001/XMLSchema-instance"
  end
  def do_spelling_suggestion(key, phrase)
    invoke("urn:doSpellingSuggestion") do |message|
      message.add "key" do |k|
        k.set_attr "xsi:type", "xsd:string"
        k.add key
      end
      message.add "phrase" do |k|
        k.set_attr "xsi:type", "xsd:string"
        k.add phrase
      end
    end
  end

end

# soap4r mappings:

def make_soap4r
  SOAP::WSDLDriverFactory.new('http://127.0.0.1:8088/mockGoogleSearchBinding?WSDL').create_rpc_driver('GoogleSearchService', 'GoogleSearchPort')
end

def make_handsoap
  TestService.new
end

service_4 = make_soap4r
service_h = make_handsoap

# TestService.logger = $stdout
# service_4.wiredump_dev = $stdout

times = ARGV[0].to_i
if times < 1
  times = 1
end
puts "Benchmarking #{times} calls ..."
Benchmark.bm(32) do |x|
  x.report("soap4r") do
    (1..times).each {
      service_4.doSpellingSuggestion("foo", "bar")
    }
  end
  Handsoap.http_driver = :curb
  Handsoap.xml_query_driver = :nokogiri
  x.report("handsoap+curb+nokogiri") do
    (1..times).each {
      service_h.do_spelling_suggestion("foo", "bar")
    }
  end
  Handsoap.http_driver = :curb
  Handsoap.xml_query_driver = :libxml
  x.report("handsoap+curb+libxml") do
    (1..times).each {
      service_h.do_spelling_suggestion("foo", "bar")
    }
  end
  Handsoap.http_driver = :curb
  Handsoap.xml_query_driver = :rexml
  x.report("handsoap+curb+rexml") do
    (1..times).each {
      service_h.do_spelling_suggestion("foo", "bar")
    }
  end
  Handsoap.http_driver = :httpclient
  Handsoap.xml_query_driver = :nokogiri
  x.report("handsoap+httpclient+nokogiri") do
    (1..times).each {
      service_h.do_spelling_suggestion("foo", "bar")
    }
  end
  Handsoap.http_driver = :httpclient
  Handsoap.xml_query_driver = :libxml
  x.report("handsoap+httpclient+libxml") do
    (1..times).each {
      service_h.do_spelling_suggestion("foo", "bar")
    }
  end
  Handsoap.http_driver = :httpclient
  Handsoap.xml_query_driver = :rexml
  x.report("handsoap+httpclient+rexml") do
    (1..times).each {
      service_h.do_spelling_suggestion("foo", "bar")
    }
  end
end
puts "---------------"
puts "Legend:"
puts "The user CPU time, system CPU time, the sum of the user and system CPU times,"
puts "and the elapsed real time. The unit of time is seconds."
