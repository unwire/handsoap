require 'rubygems'
require 'test/unit'

require "#{File.dirname(__FILE__)}/socket_server.rb"

require 'eventmachine'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require 'handsoap'
require 'handsoap/http'

class TestDeferredService < Handsoap::Service
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

  def echo(text, &block)
    async(block) do |dispatcher|
      dispatcher.request("sc002:Echo") do |m|
        m.add "text", text
      end
      dispatcher.response do |response|
        (response/"//ns:EchoResponse/ns:text").to_s
      end
    end

  end
end


SOAP_RESPONSE = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:sc0=\"http://www.wstf.org/docs/scenarios/sc002\">
   <soap:Header/>
   <soap:Body>
      <sc0:EchoResponse>
         <sc0:text>I am living in the future.</sc0:text>
      </sc0:EchoResponse>
   </soap:Body>
</soap:Envelope>".gsub(
  /\n/ , "\r\n")


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

    EventMachine.run do
      driver = Handsoap::Http.drivers[self.driver].new
      request = Handsoap::Http::Request.new("http://127.0.0.1:#{TestSocketServer.port}/")
      deferred = driver.send_http_request_async(request)

      deferred.callback do |response|
        assert_equal "Ruby", response.headers['server']
        assert_equal "OK", response.body
        assert_equal 200, response.status
        EventMachine.stop
      end
    end
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

    EventMachine.run do
      TestDeferredService.echo("I am living in the future.") do |d|
        d.callback do |text|
          assert_equal "I am living in the future.", text
          EventMachine.stop
        end
        d.errback do |mixed|
          flunk "Flunked![#{mixed}]"
          EventMachine.stop
        end
      end
    end
  end
end
