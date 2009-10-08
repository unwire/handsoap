# -*- coding: utf-8 -*-
require 'handsoap/http/drivers/abstract_driver'

module Handsoap
  module Http
    module Drivers
      class CurbDriver < AbstractDriver
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
          parse_http_part(http_client.header_str.gsub(/^HTTP.*\r\n/, ""), http_client.body_str, http_client.response_code, http_client.content_type)
        end
      end
    end
  end
end
