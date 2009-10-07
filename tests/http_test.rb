require 'rubygems'
require 'test/unit'

require 'socket'
include Socket::Constants

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/http'

class TestSocketServer

  class << self
    attr_accessor :requests, :responses, :debug
    attr_reader :port
  end

  def self.reset!
    @debug = false
    @requests = []
    @responses = []
  end

  def self.start
    @socket = Socket.new AF_INET, SOCK_STREAM, 0
    @socket.bind Socket.pack_sockaddr_in(0, "127.0.0.1")
    @port = @socket.getsockname.unpack("snA*")[1]
    self.reset!
    @socket_thread = Thread.new do
      while true
        @socket.listen 1
        client_fd, client_sockaddr = @socket.sysaccept
        client_socket = Socket.for_fd client_fd
        while @responses.any?
          @requests << client_socket.recvfrom(8192)[0]
          response = @responses.shift
          if @debug
            puts "---"
            puts @requests
            puts "---"
            puts response
          end
          client_socket.print response
        end
        client_socket.close
      end
    end
  end

  self.start
end

module AbstractHttpDriverTestCase

  def test_connect_to_example_com
    TestSocketServer.reset!
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close
Content-Type: text/plain
Date: Wed, 19 Aug 2009 12:13:45 GMT

OK".gsub(/\n/, "\r\n")

    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/")
    response = http.send_http_request(request)
    assert_equal 200, response.status
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

    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/")
    response = http.send_http_request(request)
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
Date: Wed, 19 Aug 2009 12:13:45 GMT

okeydokey".gsub(/\n/, "\r\n")

    http = Handsoap::Http.drivers[self.driver]
    request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/", :post)
    request.body = (0...1099).map{ ('a'..'z').to_a[rand(26)] }.join
    response = http.send_http_request(request)
    assert_equal "okeydokey", response.body
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

    response = Handsoap::Http.parse_http_part(header, body, 200)
    str = response.inspect do |body|
      "BODY-BEGIN : #{body} : BODY-END"
    end
    assert str =~ /BODY-BEGIN :/
  end

end
