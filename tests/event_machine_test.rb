require 'rubygems'
require 'test/unit'

require 'socket'
include Socket::Constants

require 'eventmachine'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require 'handsoap'
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


class TestService < Handsoap::Service
  endpoint :uri => "http://127.0.0.1:#{TestSocketServer.port}/", :version => 1

  def on_create_document(doc)
    doc.alias 'sc002', "http://www.wstf.org/docs/scenarios/sc002"
    doc.find("Header").add "sc002:SessionData" do |s|
      s.add "ID", "Client-1"
    end
  end

  def on_response_document(doc)
    doc.add_namespace 'ns', 'http://www.wstf.org/docs/scenarios/sc002'
  end

  def echo(text)
    deferred = invoke('sc002:Echo') do |message|
      message.add "text", text
    end
    deferred.callback {
      soap_response = deferred.options['handsoap.soap_response']
      deferred.options['echo.text'] = (soap_response.document/"//ns:EchoResponse/ns:text").to_s
    }
    deferred
  end
end


SOAP_RESPONSE = <<-XML
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:sc0="http://www.wstf.org/docs/scenarios/sc002">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>I am living in the future.</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>
XML


class TestOfEventMachineDriver < Test::Unit::TestCase
  def driver
    :event_machine
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

    EventMachine.run {
      driver = Handsoap::Http.drivers[self.driver].new
      request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/")
      deferred = driver.send_http_request(request)

      deferred.callback {
        response = deferred.options['handsoap.response']
        # TODO: Normalize response headers to match other drivers
        assert_equal "Ruby", response.headers['SERVER']
        assert_equal "OK", response.body
        assert_equal 200, response.status
        EventMachine.stop
      }
    }
  end
  
  def test_service
    TestSocketServer.reset!
    TestSocketServer.responses << "HTTP/1.1 200 OK
Server: Ruby
Connection: close
Content-Type: application/xml
Content-Length: #{SOAP_RESPONSE.size}
Date: Wed, 19 Aug 2009 12:13:45 GMT

".gsub(/\n/, "\r\n") + SOAP_RESPONSE

    Handsoap.http_driver = :event_machine
    
    EventMachine.run {
      deferred = TestService.echo("I am living in the future.")
      deferred.callback {
        assert_equal "I am living in the future.", deferred.options['echo.text']
        EventMachine.stop
      }
    }
  end
end
