# -*- coding: utf-8 -*-
require 'rubygems'
require 'test/unit'
$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require 'handsoap.rb'

def var_dump(val)
  puts val.to_yaml.gsub(/ !ruby\/object:.+$/, '')
end

class MockResponse < Handsoap::Http::Response
  attr_writer :status, :headers, :body, :parts
end

class TestService < Handsoap::Service
  attr_accessor :mock_http_response
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
    self.mock_http_response
  end

  def echo(text)
    response = invoke('sc002:Echo') do |message|
      message.add "text", text
    end
    (response.document/"//ns:EchoResponse/ns:text").to_s
  end
end

class TestServiceLegacyStyle < Handsoap::Service
  attr_accessor :mock_http_response
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
    self.mock_http_response
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
    body = '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sc0="http://www.wstf.org/docs/scenarios/sc002">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>Lirum Opossum</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>'
    TestService.mock_http_response = MockResponse.new(200, {"content-type" => ["text/xml;charset=utf-8"]}, body)
  end

  def test_normal_usecase
    assert_equal "Lirum Opossum", TestService.echo("Lirum Opossum")
  end

  def test_raises_on_http_error
    TestService.mock_http_response.status = 404
    assert_raise ::Handsoap::HttpError do
      TestService.echo("Lirum Opossum")
    end
  end

  def test_raises_on_invalid_document
    TestService.mock_http_response.body = "not xml!"
    assert_raise RuntimeError do
      TestService.echo("Lirum Opossum")
    end
  end

  def test_raises_on_fault
    TestService.mock_http_response.body = '<?xml version="1.0" encoding="UTF-8"?>
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
    TestServiceLegacyStyle.mock_http_response = TestService.mock_http_response
    assert_equal "Lirum Opossum", TestServiceLegacyStyle.echo("Lirum Opossum")
  end

  def test_multipart_response
    body = '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sc0="http://www.wstf.org/docs/scenarios/sc002">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>Lirum Opossum</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>'
    TestService.mock_http_response.parts = [Handsoap::Http::Part.new({}, body, nil)]
    assert_equal "Lirum Opossum", TestService.echo("Lirum Opossum")
  end

  def test_raises_on_no_document
    TestService.mock_http_response.status = 202
    TestService.mock_http_response.body = ''
    assert_raise RuntimeError do
      TestService.echo("Lirum Opossum")
    end
  end

end
