
module Handsoap

  module Http

    class Request
      attr_reader :url, :http_method, :headers, :body
      attr_writer :body
      def initialize(url, http_method = :get)
        @url = url
        @http_method = http_method
        @headers = {}
        @body = nil
      end
      def add_header(key, value)
        if @headers[key].nil?
          @headers[key] = []
        end
        @headers[key] << value
      end
      def set_header(key, value)
        if value.nil?
          @headers[key] = nil
        else
          @headers[key] = [value]
        end
      end
    end

    class Part
      attr_reader :headers, :body, :parts
      def initialize(headers, body, parts = nil)
        @headers = headers
        @body = body
        @parts = parts
      end
      def multipart?
        !! @parts
      end
    end

    class Response < Part
      attr_reader :status
      def initialize(status, headers, body, parts = nil)
        @status = status
        super(headers, body, parts)
      end
    end

    @@drivers =  {
      :net_http => NetHttp,
      :curb => Curb,
      :httpclient => Httpclient
    }

    def self.drivers
      @@drivers
    end

    # driver for httpclient
    module Httpclient
      def self.self.load!
        require 'httpclient'
      end
      def self.send_http_request(request)
        http_client = HTTPClient.new
        # pack headers
        headers = []
        request.headers.each do |k,v|
          v.each do |value|
            headers << [k, value]
          end
        end
        response = http_client.request(request.http_method, request.url, nil, request.body, headers)
        # TODO wrap response
        # response.status, response.contenttype, response.header.all.join("\r\n"), response.content
      end
    end

    # driver for curb
    module Curb
      def self.self.load!
        require 'curb'
      end
      def self.send_http_request(request)
        http_client = Curl::Easy.new(request.url)
        # pack headers
        headers = []
        request.headers.each do |k,v|
          v.each do |value|
            # TODO mime-encode header values?
            headers << "#{k}: #{value}"
          end
        end
        http_client.headers = headers
        # I don't think put/delete is actually supported ..
        case request.http_method
        when :get
          http_client.http_get
        when :post
          http_client.http_post(request.body)
        when :put
          http_client.http_put(request.body)
        when :delete
          http_client.http_delete
        else
          raise "Unsupported request method #{request.http_method}"
        end
        # TODO wrap response
        # http_client.response_code, http_client.content_type, http_client.header_str, http_client.body_str
      end
    end

    # driver for net/http
    module NetHttp
      def self.self.load!
        require 'net/http'
      end
      def self.send_http_request(request)
        url = request.url
        unless url.kind_of? URI::Generic
          url = URI.parse(url)
        end
        URI::Generic.send(:public, :path_query) # hackety hack
        path = url.path_query
        http_request = case request.http_method
                       when :get
                         Net::HTTP::Get.new(path)
                       when :post
                         Net::HTTP::Post.new(path)
                       when :put
                         Net::HTTP::Put.new(path)
                       when :delete
                         Net::HTTP::Delete.new(path)
                       else
                         raise "Unsupported request method #{request.http_method}"
                       end
        http_client = Net::HTTP.new(url.host, url.port)
        http_client.read_timeout = 120
        # TODO body, headers
        # debug_output = StringIO.new
        # http_client.set_debug_output debug_output
       http_response = http_client.start do |http|
          http.request(http_request)
        end
        # puts debug_output.string
        # TODO wrap response
      end
    end

    # Parses a multipart http-response body into parts.
    # +boundary+ is a string of the boundary token.
    # +content_io+ is either a string or an IO. If it's an IO, then content_length must be specified.
    # +content_length+ (optional) is an integer, specifying the length of +content_io+
    #
    # This code is lifted from cgi.rb
    #
    def self.parse_multipart(boundary, content_io, content_length = nil)
      if content_io.kind_of? String
        content_length = content_io.length
        content_io = StringIO.new(content_io, 'r')
      elsif !(content_io.kind_of? IO) || content_length.nil?
        raise "Second argument must be String or IO with content_length"
      end

      boundary = "--" + boundary
      quoted_boundary = Regexp.quote(boundary, "n")
      buf = ""
      bufsize = 10 * 1024
      boundary_end = ""

      # start multipart/form-data
      content_io.binmode if defined? content_io.binmode
      boundary_size = boundary.size + "\r\n".size
      content_length -= boundary_size
      status = content_io.read(boundary_size)
      if nil == status
        raise EOFError, "no content body"
      elsif boundary + "\r\n" != status
        raise EOFError, "bad content body"
      end

      parts = []

      loop do
        head = nil
        if 10240 < content_length
          require "tempfile"
          body = Tempfile.new("Handsoap")
        else
          begin
            require "stringio"
            body = StringIO.new
          rescue LoadError
            require "tempfile"
            body = Tempfile.new("Handsoap")
          end
        end
        body.binmode if defined? body.binmode

        until head and /#{quoted_boundary}(?:\r\n|--)/n.match(buf)

          if (not head) and /\r\n\r\n/n.match(buf)
            buf = buf.sub(/\A((?:.|\n)*?\r\n)\r\n/n) do
              head = $1.dup
              ""
            end
            next
          end

          if head and ( ("\r\n" + boundary + "\r\n").size < buf.size )
            body.print buf[0 ... (buf.size - ("\r\n" + boundary + "\r\n").size)]
            buf[0 ... (buf.size - ("\r\n" + boundary + "\r\n").size)] = ""
          end

          c = if bufsize < content_length
                content_io.read(bufsize)
              else
                content_io.read(content_length)
              end
          if c.nil? || c.empty?
            raise EOFError, "bad content body"
          end
          buf.concat(c)
          content_length -= c.size
        end

        buf = buf.sub(/\A((?:.|\n)*?)(?:[\r\n]{1,2})?#{quoted_boundary}([\r\n]{1,2}|--)/n) do
          body.print $1
          if "--" == $2
            content_length = -1
          end
          boundary_end = $2.dup
          ""
        end

        body.rewind
        parts << {:head => head, :body => body.read(body.size)}

        break if buf.size == 0
        break if content_length == -1
      end
      raise EOFError, "bad boundary end of body part" unless boundary_end =~ /--/
      parts
    end

    def self.parse_headers(header_str)
      # TODO
    end

  end
end
