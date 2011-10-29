# -*- coding: utf-8 -*-
require 'rubygems'
require 'test/unit'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/xml_query_front'
require 'handsoap/service'

class ParseFaultTestCase < Test::Unit::TestCase
  def get_fault_11
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

  def get_fault_12
    xml_doc = '<?xml version="1.0" ?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope"
            xmlns:rpc="http://www.w3.org/2003/05/soap-rpc">
  <env:Body>
   <env:Fault>
     <env:Code>
       <env:Value>env:Sender</env:Value>
       <env:Subcode>
        <env:Value>rpc:BadArguments</env:Value>
       </env:Subcode>
     </env:Code>
     <env:Reason>
      <env:Text xml:lang="en-US">Processing error</env:Text>
      <env:Text xml:lang="cs">Chyba zpracování</env:Text>
     </env:Reason>
     <env:Detail>
      <e:myFaultDetails
        xmlns:e="http://travelcompany.example.org/faults">
        <e:message>Name does not match card number</e:message>
        <e:errorcode>999</e:errorcode>
      </e:myFaultDetails>
     </env:Detail>
   </env:Fault>
 </env:Body>
</env:Envelope>'
    Handsoap::XmlQueryFront.parse_string(xml_doc, Handsoap.xml_query_driver)
  end

  # Added to test issue 6, found here: http://github.com/unwire/handsoap/issues#issue/6
  # this is for SOAP 1.1 btw
  def get_fault_with_namespace
    xml_doc = '<?xml version="1.0" encoding="UTF-8"?>
<a:Envelope xmlns:a="http://schemas.xmlsoap.org/soap/envelope/">
  <a:Body>
      <a:Fault>
        <a:faultcode>a:Client</a:faultcode>
      <a:faultstring>Failed to parse the request</a:faultstring>
      <a:detail>Invalid parameter</a:detail>
    </a:Fault>
  </a:Body>
</a:Envelope>'

    Handsoap::XmlQueryFront.parse_string(xml_doc, Handsoap.xml_query_driver)
  end

  # Tests that SOAP1.1 faults can be parsed
  def test_can_parse_soap_fault_11
    envelope_namespace = "http://schemas.xmlsoap.org/soap/envelope/"

    node = get_fault_11.xpath('/env:Envelope/env:Body/descendant-or-self::env:Fault', { 'env' => envelope_namespace })
    fault = Handsoap::Fault.from_xml(node, :namespace => envelope_namespace)

    assert_kind_of Handsoap::Fault, fault
    assert_equal 'soap:Server', fault.code
    assert_equal 'Error while blackList account: the application does not exist', fault.reason
  end

  # Tests that SOAP1.2 faults can be parsed
  def test_can_parse_soap_fault_12
    envelope_namespace = "http://www.w3.org/2003/05/soap-envelope"

    node = get_fault_12.xpath('/env:Envelope/env:Body/descendant-or-self::env:Fault', { 'env' => envelope_namespace })
    fault = Handsoap::Fault.from_xml(node, :namespace => envelope_namespace)

    assert_kind_of Handsoap::Fault, fault
    assert_equal 'env:Sender', fault.code
    assert_equal 'Processing error', fault.reason
  end

  # Added to test issue 6, found here: http://github.com/unwire/handsoap/issues#issue/6
  # This is for SOAP 1.1 btw
  def test_can_parse_soap_fault_with_namespace
    envelope_namespace = "http://schemas.xmlsoap.org/soap/envelope/"

    node = get_fault_with_namespace.xpath('/env:Envelope/env:Body/descendant-or-self::env:Fault', { 'env' => envelope_namespace })
    fault = Handsoap::Fault.from_xml(node, :namespace => envelope_namespace)

    assert_kind_of Handsoap::Fault, fault
    assert_equal 'a:Client', fault.code
    assert_equal 'Failed to parse the request', fault.reason
  end
end
