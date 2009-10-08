# -*- coding: utf-8 -*-
require 'handsoap/http/drivers/abstract_driver'

module Handsoap
  module Http
    module Drivers
      class EventMachineDriver < AbstractDriver
        def self.load!
          require 'eventmachine'
          require 'em-http'
        end

        def send_http_request(request)          
          emr = EventMachine::HttpRequest.new(request.url)
          
          # Set credentials. The driver will negotiate the actual scheme
          if request.username && request.password
            request.headers['authorization'] = [request.username, request.password]
          end
          
          # I don't think put/delete is actually supported ..
          case request.http_method
          when :get
            deferred = emr.get :head => request.headers
          when :post
            deferred = emr.post :head => request.headers, :body => request.body
          when :put
            deferred = emr.put :head => request.headers, :body => request.body
          when :delete
            deferred = emr.delete
          else
            raise "Unsupported request method #{request.http_method}"
          end
          
          deferred.callback {
            deferred.options['handsoap.response'] = parse_http_part(deferred.response_header, deferred.response, deferred.response_header.status)
          }
          
          deferred
        end
      end
    end
  end
end
