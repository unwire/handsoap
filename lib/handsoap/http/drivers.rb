# -*- coding: utf-8 -*-
require 'handsoap/http/drivers/mock_driver'
require 'handsoap/http/drivers/curb_driver'
require 'handsoap/http/drivers/http_client_driver'
require 'handsoap/http/drivers/net_http_driver'

module Handsoap
  module Http
    @@drivers = {
      :net_http => Drivers::NetHttpDriver,
      :curb => Drivers::CurbDriver,
      :httpclient => Drivers::HttpClientDriver,
    }

    def self.drivers
      @@drivers
    end
  end
end
