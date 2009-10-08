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
end
