# -*- coding: utf-8 -*-
module Handsoap

  # The Handsoap::Http module provides a uniform interface to various http drivers.
  module Http

    # Represents a HTTP Request.
    class Request
      attr_reader :url, :http_method, :headers, :body, :username, :password
      attr_writer :body, :http_method
      def initialize(url, http_method = :get)
        @url = url
        @http_method = http_method
        @headers = {}
        @body = nil
        @username = nil
        @password = nil
      end
      def set_auth(username, password)
        @username = username
        @password = password
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
      def inspect
        "===============\n" +
          "--- Request ---\n" +
          "#{http_method.to_s.upcase} #{url}\n" +
          (
           if username && password
             "Auth credentials: #{username}:#{password}\n"
           else
             ""
           end
           ) +
          (
           if headers.any?
             "---\n" + headers.map { |key,values| values.map {|value| key + ": " + value + "\n" }.join("")  }.join("")
           else
             ""
           end
           ) +
          (
           if body
             "---\n" + body
           else
             ""
           end
           )
      end
    end

    # Represents a HTTP Part.
    # For simple HTTP-requests there is only one part, which is the response.
    class Part
      attr_reader :headers, :body, :parts
      def initialize(headers, body, parts = nil)
        @headers = headers
        @body = body
        @parts = parts
      end
      # Returns a header.
      # Returns String | Array | nil
      def [](key)
        key.to_s.downcase!
        (@headers[key] && @headers[key].length == 1) ? @headers[key].first : @headers[key]
      end
      # Returns the mime-type part of the content-type header
      def mime_type
        @headers['content-type'].first.match(/^[^;]+/).to_s if @headers['content-type']
      end
      # Returns the charset part of the content-type header
      def charset
        if @headers['content-type']
          match_data = @headers['content-type'].first.match(/^[^;]+; charset=([^;]+)/)
          if match_data
            match_data[1].to_s
          end
        end
      end
      def multipart?
        !! @parts
      end
      def inspect(&block)
        str = inspect_head
        if headers.any?
          str << headers.map { |key,values| values.map {|value| Handsoap::Http.normalize_header_key(key) + ": " + value + "\n" }.join("")  }.join("")
        end
        if body
          if multipart?
            if block_given?
              str << parts.map{|part| part.inspect(&block) }.join("")
            else
              str << parts.map{|part| part.inspect }.join("")
            end
          elsif body
            str <<  "---\n"
            if block_given?
              str << yield(body)
            else
              str << body
            end
            str << "\n---"
          end
        end
      end
      private
      def inspect_head
        "--- Part ---\n"
      end
    end

    # Represents a HTTP Response.
    class Response < Part
      attr_reader :status
      def initialize(status, headers, body, parts = nil)
        @status = status.to_i
        super(headers, body, parts)
      end
      def primary_part
        # Strictly speaking, the main part doesn't need to be first, but until proven otherwise, we'll just assume that.
        if multipart?
          parts.first
        else
          self
        end
      end
      private
      def inspect_head
        "--- Response ---\n" + "HTTP Status: #{status}\n"
      end
    end

    # driver for httpclient
    module Httpclient
      def self.load!
        require 'httpclient'
      end
      def self.send_http_request(request)
        self.load!
        http_client = HTTPClient.new
        # Set credentials. The driver will negotiate the actual scheme
        if request.username && request.password
          domain = request.url.match(/^(http(s?):\/\/[^\/]+\/)/)[1]
          http_client.set_auth(domain, request.username, request.password)
        end
        # pack headers
        headers = request.headers.inject([]) do |arr, (k,v)|
          arr + v.map {|x| [k,x] }
        end
        response = http_client.request(request.http_method, request.url, nil, request.body, headers)
        response_headers = response.header.all.inject({}) do |h, (k, v)|
          k.downcase!
          if h[k].nil?
            h[k] = [v]
          else
            h[k] << v
          end
          h
        end
        Handsoap::Http.parse_http_part(response_headers, response.content, response.status, response.contenttype)
      end
    end

    # driver for curb
    module Curb
      def self.load!
        require 'curb'
      end
      def self.send_http_request(request)
        self.load!
        http_client = Curl::Easy.new(request.url)
        # Set credentials. The driver will negotiate the actual scheme
        if request.username && request.password
          http_client.userpwd = [request.username, ":", request.password].join
        end
        # pack headers
        headers = request.headers.inject([]) do |arr, (k,v)|
          arr + v.map {|x| "#{k}: #{x}" }
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
        Handsoap::Http.parse_http_part(http_client.header_str.gsub(/^HTTP.*\r\n/, ""), http_client.body_str, http_client.response_code, http_client.content_type)
      end
    end

    # driver for net/http
    module NetHttp
      def self.load!
        require 'net/http'
        require 'uri'
      end
      def self.send_http_request(request)
        self.load!
        url = request.url
        unless url.kind_of? ::URI::Generic
          url = ::URI.parse(url)
        end
        ::URI::Generic.send(:public, :path_query) # hackety hack
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
        if request.username && request.password
          # TODO: http://codesnippets.joyent.com/posts/show/1075
          http_request.basic_auth request.username, request.password
        end
        request.headers.each do |k, values|
          values.each do |v|
            http_request.add_field(k, v)
          end
        end
        http_request.body = request.body
        # require 'stringio'
        # debug_output = StringIO.new
        # http_client.set_debug_output debug_output
        http_response = http_client.start do |client|
          client.request(http_request)
        end
        # puts debug_output.string
        # hacky-wacky
        def http_response.get_headers
          @header.inject({}) do |h, (k, v)|
            h[k.downcase] = v
            h
          end
        end
        # net/http only supports basic auth. We raise a warning if the server requires something else.
        if http_response.code == 401 && http_response.get_headers['www-authenticate']
          auth_type = http_response.get_headers['www-authenticate'].chomp.match(/\w+/)[0].downcase
          if auth_type != "basic"
            raise "Authentication type #{auth_type} is unsupported by net/http"
          end
        end
        Handsoap::Http.parse_http_part(http_response.get_headers, http_response.body, http_response.code)
      end
    end

    # A mock driver for your testing needs.
    #
    # To use it, create a new instance and assign to +Handsoap::Http.drivers+. Then configure +Handsoap::Service+ to use it:
    #
    #     Handsoap::Http.drivers[:mock] = Handsoap::Http::HttpMock.new :status => 200, :headers => headers, :content => body
    #     Handsoap.http_driver = :mock
    #
    # Remember that headers should use \r\n, rather than \n.
    class HttpMock
      attr_accessor :mock, :last_request, :is_loaded
      def initialize(mock)
        @mock = mock
        @is_loaded = false
      end
      def load!
        is_loaded = true
      end
      def send_http_request(request)
        @last_request = request
        Handsoap::Http.parse_http_part(mock[:headers], mock[:content], mock[:status], mock[:content_type])
      end
    end

    # Parses a raw http response into a +Response+ or +Part+ object.
    def self.parse_http_part(headers, body, status = nil, content_type = nil)
      if headers.kind_of? String
        headers = parse_headers(headers)
      end
      if content_type.nil? && headers['content-type']
        content_type = headers['content-type'].first
      end
      boundary = parse_multipart_boundary(content_type)
      parts = if boundary
        parse_multipart(boundary, body).map {|raw_part| parse_http_part(raw_part[:head], raw_part[:body]) }
      end
      if status.nil?
        Handsoap::Http::Part.new(headers, body, parts)
      else
        Handsoap::Http::Response.new(status, headers, body, parts)
      end
    end

    # Content-Type header string -> mime-boundary | nil
    def self.parse_multipart_boundary(content_type)
      if %r|\Amultipart.*boundary=\"?([^\";,]+)\"?|n.match(content_type)
        $1.dup
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

    # lifted from webrick/httputils.rb
    def self.parse_headers(raw)
      header = Hash.new([].freeze)
      field = nil
      raw.gsub(/^(\r\n)+|(\r\n)+$/, '').each {|line|
        case line
        when /^([A-Za-z0-9!\#$%&'*+\-.^_`|~]+):\s*(.*?)\s*\z/om
          field, value = $1, $2
          field.downcase!
          header[field] = [] unless header.has_key?(field)
          header[field] << value
        when /^\s+(.*?)\s*\z/om
          value = $1
          unless field
            raise "bad header '#{line.inspect}'."
          end
          header[field][-1] << " " << value
        else
          raise "bad header '#{line.inspect}'."
        end
      }
      header.each {|key, values|
        values.each {|value|
          value.strip!
          value.gsub!(/\s+/, " ")
        }
      }
      header
    end

    def self.normalize_header_key(key)
      key.split("-").map{|s| s.downcase.capitalize }.join("-")
    end

    @@drivers =  {
      :net_http => NetHttp,
      :curb => Curb,
      :httpclient => Httpclient
    }

    def self.drivers
      @@drivers
    end

  end
end
