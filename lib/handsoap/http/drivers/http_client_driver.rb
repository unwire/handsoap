# -*- coding: utf-8 -*-
require 'handsoap/http/drivers/abstract_driver'

module Handsoap
  module Http
    module Drivers
      class HttpClientDriver < AbstractDriver
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
          parse_http_part(response_headers, response.content, response.status, response.contenttype)
        end
      end
    end
  end
end
