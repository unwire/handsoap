require 'socket'
include Socket::Constants

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
