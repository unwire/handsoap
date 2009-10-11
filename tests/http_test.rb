require 'rubygems'
require 'test/unit'

require "#{File.dirname(__FILE__)}/socket_server.rb"

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/http'

module AbstractHttpDriverTestCase

  def setup
    Handsoap::Http.drivers[self.driver].load!
  end

  def test_connect_to_example_com
    TestSocketServer.reset!
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close
Content-Type: text/plain
Content-Length: 2
Date: Wed, 19 Aug 2009 12:13:45 GMT

OK".gsub(/\n/, "\r\n")

    driver = Handsoap::Http.drivers[self.driver].new
    request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/")
    response = driver.send_http_request(request)
    assert_equal 200, response.status
    assert_equal ["Ruby"], response.headers['server']
    assert_equal "OK", response.body
  end

  def test_chunked
    TestSocketServer.reset!
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: Keep-Alive
Content-Type: text/plain
Transfer-Encoding: chunked
Date: Wed, 19 Aug 2009 12:13:45 GMT

b
Hello World
0

".gsub(/\n/, "\r\n")

    driver = Handsoap::Http.drivers[self.driver].new
    request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/")
    response = driver.send_http_request(request)
    assert_equal "Hello World", response.body
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

  # Curl will use 100-Continue if Content-Length > 1024
  def test_continue
    TestSocketServer.reset!
    # TestSocketServer.debug  = true
    TestSocketServer.responses << "HTTP/1.1 100 Continue

".gsub(/\n/, "\r\n")
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close
Content-Type: text/plain
Content-Length: 9
Date: Wed, 19 Aug 2009 12:13:45 GMT

okeydokey".gsub(/\n/, "\r\n")

    driver = Handsoap::Http.drivers[self.driver].new
    request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/", :post)
    request.body = (0...1099).map{ ('a'..'z').to_a[rand(26)] }.join
    response = driver.send_http_request(request)
    assert_equal "okeydokey", response.body
  end

  def test_no_retain_cookie_between_requests_by_default
    driver = Handsoap::Http.drivers[self.driver].new

    TestSocketServer.reset!
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close
Content-Type: text/plain
Date: Wed, 19 Aug 2009 12:13:45 GMT
Set-Cookie: SessionId=s5x1rcvuktc3c455hgu23bxx; path=/; HttpOnly

okeydokey".gsub(/\n/, "\r\n")

    request = Handsoap::Http::Request.new("http://localhost:#{TestSocketServer.port}/", :post)
    response = driver.send_http_request(request)
    assert_equal "okeydokey", response.body

    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close

The second body".gsub(/\n/, "\r\n")

    driver.send_http_request(request)
    # second request must NOT include the Cookie returned in Set-Cookie on the first request
    assert ! TestSocketServer.requests.last.include?("Cookie: SessionId=s5x1rcvuktc3c455hgu23bxx")
  end

  def test_retain_cookie_between_requests_when_cookies_enabled
    driver = Handsoap::Http.drivers[self.driver].new
    driver.enable_cookies = true  # enable in-built Cookie support in Curb

    TestSocketServer.reset!
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close
Content-Type: text/plain
Date: Wed, 19 Aug 2009 12:13:45 GMT
Set-Cookie: SessionId=s5x1rcvuktc3c455hgu23bxx; path=/; HttpOnly

okeydokey".gsub(/\n/, "\r\n")

    request = Handsoap::Http::Request.new("http://localhost:#{TestSocketServer.port}/", :post)
    response = driver.send_http_request(request)
    assert_equal "okeydokey", response.body

    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close

The second body".gsub(/\n/, "\r\n")

    driver.send_http_request(request)
    # second request must include the Cookie returned in Set-Cookie on the first request
    assert TestSocketServer.requests.last.include?("Cookie: SessionId=s5x1rcvuktc3c455hgu23bxx")
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
    parts = Handsoap::Http::Drivers::AbstractDriver.new.parse_multipart(boundary, content_io)
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
    driver = Handsoap::Http::Drivers::AbstractDriver.new
    parts = driver.parse_multipart(boundary, content_io)
    assert_equal 1, parts.size
    assert parts.first[:body] =~ /^foobar/
  end

  def test_parse_multipart_request
    header = 'Server: Apache-Coyote/1.1
Content-Type: multipart/related; boundary=MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249656297568; type="application/xop+xml"; start="0.urn:uuid:FF5B45112F1A1EA3831249656297569@apache.org"; start-info="text/xml"
Transfer-Encoding: chunked
Date: Fri, 07 Aug 2009 14:44:56 GMT'.gsub(/\n/, "\r\n")

    body = '--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249656297568
Content-Type: application/xop+xml; charset=UTF-8; type="text/xml"
Content-Transfer-Encoding: binary
Content-ID: <0.urn:uuid:FF5B45112F1A1EA3831249656297569@apache.org>

Lorem ipsum
--MIMEBoundaryurn_uuid_FF5B45112F1A1EA3831249656297568--
'.gsub(/\n/, "\r\n")

    driver = Handsoap::Http::Drivers::AbstractDriver.new
    response = driver.parse_http_part(header, body, 200)
    str = response.inspect do |body|
      "BODY-BEGIN : #{body} : BODY-END"
    end
    assert str =~ /BODY-BEGIN :/
  end

end
