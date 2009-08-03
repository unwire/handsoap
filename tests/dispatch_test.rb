# -*- coding: utf-8 -*-
require 'rubygems'
require 'test/unit'
$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require 'handsoap.rb'

def var_dump(val)
  puts val.to_yaml.gsub(/ !ruby\/object:.+$/, '')
end

class TestService < Handsoap::Service
  attr_accessor :mock_status, :mock_body, :mock_content_type, :mock_multipart, :mock_parts
  endpoint :uri => 'http://example.com', :version => 1
  def on_create_document(doc)
    doc.alias 'sc002', "http://www.wstf.org/docs/scenarios/sc002"
    doc.find("Header").add "sc002:SessionData" do |s|
      s.add "ID", "Client-1"
    end
  end
  def on_response_document(doc)
    doc.add_namespace 'ns', 'http://www.wstf.org/docs/scenarios/sc002'
  end
  def send_http_request(uri, post_body, headers)
    return { :status => self.mock_status, :body => self.mock_body, :content_type => self.mock_content_type, :multipart => self.mock_multipart, :parts => self.mock_parts.nil? ? [:head => "Wheres your head at?", :body => self.mock_body] : self.mock_parts }
  end
  def echo(text)
    response = invoke('sc002:Echo') do |message|
      message.add "text", text
    end
    (response.document/"//ns:EchoResponse/ns:text").to_s
  end
end

class TestServiceLegacyStyle < Handsoap::Service
  attr_accessor :mock_status, :mock_body, :mock_content_type, :mock_multipart, :mock_parts
  endpoint :uri => 'http://example.com', :version => 1
  def on_create_document(doc)
    doc.alias 'sc002', "http://www.wstf.org/docs/scenarios/sc002"
    doc.find("Header").add "sc002:SessionData" do |s|
      s.add "ID", "Client-1"
    end
  end
  def ns
    { 'ns' => 'http://www.wstf.org/docs/scenarios/sc002' }
  end
  def send_http_request(uri, post_body, headers)
    return { :status => self.mock_status, :body => self.mock_body, :content_type => self.mock_content_type, :multipart => self.mock_multipart, :parts => self.mock_parts.nil? ? [:head => "Wheres your head at?", :body => self.mock_body] : self.mock_parts }
  end
  def echo(text)
    response = invoke('sc002:Echo') do |message|
      message.add "text", text
    end
    xml_to_str(response.document, "//ns:EchoResponse/ns:text/text()")
  end
end

class TestOfDispatch < Test::Unit::TestCase
  def setup
    TestService.mock_status = 200
    TestService.mock_multipart = true
    TestService.mock_parts = nil
    TestService.mock_body = '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sc0="http://www.wstf.org/docs/scenarios/sc002">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>Lirum Opossum</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>'
    TestService.mock_content_type = "text/xml;charset=utf-8"
  end
  def test_normal_usecase
    assert_equal "Lirum Opossum", TestService.echo("Lirum Opossum")
  end
  def test_raises_on_http_error
    TestService.mock_status = 404
    assert_raise RuntimeError do
      TestService.echo("Lirum Opossum")
    end
  end
  def test_raises_on_invalid_document
    TestService.mock_body = "not xml!"
    assert_raise RuntimeError do
      TestService.echo("Lirum Opossum")
    end
  end
  def test_raises_on_fault
    TestService.mock_body = '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Server</faultcode>
      <faultstring>Not a ninja</faultstring>
      <detail/>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>'
    assert_raise Handsoap::Fault do
      TestService.echo("Lirum Opossum")
    end
  end
  def test_legacy_parser_helpers
    TestServiceLegacyStyle.mock_status = TestService.mock_status
    TestServiceLegacyStyle.mock_body = TestService.mock_body
    TestServiceLegacyStyle.mock_content_type = TestService.mock_content_type
    assert_equal "Lirum Opossum", TestServiceLegacyStyle.echo("Lirum Opossum")
  end



  def test_multipart_response
    TestService.mock_status = 200
    TestService.mock_multipart = true
    TestService.mock_body = '--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646
Content-Type: application/xop+xml; charset=UTF-8; type="text/xml"
Content-Transfer-Encoding: binary
Content-ID: <0.urn:uuid:FF5B45112F1A1EA3831249088019647@apache.org>

<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sc0="http://www.wstf.org/docs/scenarios/sc002">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>Lirum Opossum</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>
--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646--'
    TestService.mock_parts = [{:head => 'No head', :body => '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sc0="http://www.wstf.org/docs/scenarios/sc002">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>Lirum Opossum</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>'}]
    TestService.mock_content_type = 'Content-Type: multipart/related; boundary=MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646; type="application/xop+xml"; start="0.urn:uuid:FF5B45112F1A1EA3831249088019647@apache.org"; start-info="text/xml"'
    assert_equal "Lirum Opossum", TestService.echo("Lirum Opossum")
  end

end
