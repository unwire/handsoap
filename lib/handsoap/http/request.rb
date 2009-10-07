# -*- coding: utf-8 -*-

module Handsoap
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
  end
end
