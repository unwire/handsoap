require 'rubygems'
require 'test/unit'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/xml_query_front'
require 'handsoap/service'

class ParseFaultTestCase < Test::Unit::TestCase
  def get_xml_document
    xml_doc = '<?xml version="1.0" encoding="UTF-8"?>
  <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
      <soap:Fault>
        <faultcode>soap:Server</faultcode>
        <faultstring>Error while blackList account: the application does not exist</faultstring>
        <detail/>
      </soap:Fault>
    </soap:Body>
  </soap:Envelope>'
    Handsoap::XmlQueryFront.parse_string(xml_doc, Handsoap.xml_query_driver)
  end
  def test_can_parse_soap_fault
    envelope_namespace = "http://schemas.xmlsoap.org/soap/envelope/"
    node = get_xml_document.xpath('/env:Envelope/env:Body/descendant-or-self::env:Fault', { 'env' => envelope_namespace })
    fault = Handsoap::Fault.from_xml(node, :namespace => envelope_namespace)
    assert_kind_of Handsoap::Fault, fault
    assert_equal 'soap:Server', fault.code
    assert_equal 'Error while blackList account: the application does not exist', fault.reason
  end
end
