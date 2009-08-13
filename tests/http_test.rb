require 'rubygems'
require 'test/unit'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/http'

module AbstractHttpDriverTestCase
  def test_connect_to_example_com
    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://www.example.com/")
    # p request
    response = http.send_http_request(request)
    # p response
    assert_equal 200, response.status
  end
end

class TestOfNetHttpDriver < Test::Unit::TestCase
  include AbstractHttpDriverTestCase
  def driver
    :net_http
  end
end

class TestOfCurbDriver < Test::Unit::TestCase
  include AbstractHttpDriverTestCase
  def driver
    :curb
  end
end

class TestOfHttpclientDriver < Test::Unit::TestCase
  include AbstractHttpDriverTestCase
  def driver
    :httpclient
  end
end

class TestOfHttp < Test::Unit::TestCase
  def test_parse_multipart_small
    boundary = 'MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646'
    content_io = '--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646
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
--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646--
'
    content_io.gsub!(/\n/, "\r\n")
    parts = Handsoap::Http.parse_multipart(boundary, content_io)
    assert_equal 1, parts.size
    assert parts.first[:body] =~ /^<soap:Envelope/
  end

  def test_parse_multipart_large
    boundary = 'MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646'
    content_io = '--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646
Content-Type: application/xop+xml; charset=UTF-8; type="text/xml"
Content-Transfer-Encoding: binary
Content-ID: <0.urn:uuid:FF5B45112F1A1EA3831249088019647@apache.org>

foobar' + ((0..10240).map { |i| (rand(27) + 65).chr }.join) + '
--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249088019646--
'
    content_io.gsub!(/\n/, "\r\n")
    parts = Handsoap::Http.parse_multipart(boundary, content_io)
    assert_equal 1, parts.size
    assert parts.first[:body] =~ /^foobar/
  end

  def test_parse_multipart_request
    raw_header = 'Server: Apache-Coyote/1.1
Content-Type: multipart/related; boundary=MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249656297568; type="application/xop+xml"; start="0.urn:uuid:FF5B45112F1A1EA3831249656297569@apache.org"; start-info="text/xml"
Transfer-Encoding: chunked
Date: Fri, 07 Aug 2009 14:44:56 GMT'.gsub(/\n/, "\r\n")

    raw_body = '--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249656297568
Content-Type: application/xop+xml; charset=UTF-8; type="text/xml"
Content-Transfer-Encoding: binary
Content-ID: <0.urn:uuid:FF5B45112F1A1EA3831249656297569@apache.org>

Lorem ipsum
--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249656297568--
'.gsub(/\n/, "\r\n")

    response = Handsoap::Http.parse_http_part(raw_header, raw_body, 200)
    str = response.inspect do |body|
      "BODY-BEGIN : #{body} : BODY-END"
    end
    assert str =~ /BODY-BEGIN :/
  end

end
