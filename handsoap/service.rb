# -*- coding: utf-8 -*-
require 'rubygems'
require 'httpclient'
require 'nokogiri'
require 'handsoap/xml_mason'

module Handsoap

  class Response
    def initialize(http_response)
      @http_response = http_response
      @document = :lazy
      @fault = :lazy
    end
    def http_response
      @http_response
    end
    def document?
      !! document
    end
    def document
      if @document == :lazy
        doc = Nokogiri::XML(http_response.content)
        @document = (doc && doc.root && doc.errors.empty?) ? doc : nil
      end
      return @document
    end
    def fault?
      !! fault
    end
    def fault
      if @fault == :lazy
        node = document? ? document.xpath('/env:Envelope/env:Body/env:Fault', { 'env' => 'http://www.w3.org/2003/05/soap-envelope' }) : false
        @fault = node ? Fault.from_xml(node) : nil
      end
      return @fault
    end
  end

  class Fault
    attr_reader :code, :reason
    def initialize(code, reason)
      @code = code
      @reason = reason
    end
    def self.from_xml(node)
      ns = { 'env' => 'http://www.w3.org/2003/05/soap-envelope' }
      self.new node.xpath('./env:Code/env:Value/text()', ns), node.xpath('./env:Reason/env:Text[1]/text()', ns)
    end
  end

  class Service
    @@logger = nil
    def self.logger=(io)
      @@logger = io
    end
    def self.endpoint(uri)
      @uri = uri
    end
    def self.map_method(mapping)
      if @mapping.nil?
        @mapping = {}
      end
      @mapping.merge! mapping
    end
    def self.on_create_document(&block)
      @create_document_callback = block
    end
    def self.fire_on_create_document(doc)
      if @create_document_callback
        @create_document_callback.call doc
      end
    end
    def self.on_create_http(&block)
      @create_http_callback = block
    end
    def self.fire_on_create_http(http)
      if @create_http_callback
        @create_http_callback.call http
      end
    end
    def self.uri
      @uri
    end
    def self.get_mapping(name)
      @mapping[name]
    end
    def method_missing(name)
      action = self.class.get_mapping(name)
      if action
        doc = make_envelope do |body|
          body.add action
        end
        if block_given?
          yield doc.find(action)
        end
        dispatch doc
      end
    end
    private
    def debug(message)
      @@logger.puts(message) if @@logger
    end
    def http
      if @http.nil?
        @http = HTTPClient.new
        self.class.fire_on_create_http @http
      end
      return @http
    end
    def dispatch(doc)
      debug "==============="
      debug "--- Request ---"
      debug "URI: %s" % [self.class.uri]
      debug "---"
      body = doc.to_s
      debug body
      response = http.post(self.class.uri, body)
      debug "--- Response ---"
      debug "HTTP Status: %s" % [response.status]
      debug "Content-Type: %s" % [response.contenttype]
      debug "---"
      debug response.content
      if response.status < 400
        return Response.new(response)
      else
        raise "Http Error #{response.status}"
      end
    end
    def make_envelope
      doc = XmlMason::Document.new do |doc|
        doc.alias 'env', "http://www.w3.org/2003/05/soap-envelope"
        doc.add "env:Envelope" do |env|
          env.add "Header"
          env.add "Body"
        end
      end
      self.class.fire_on_create_document doc
      if block_given?
        yield doc.find("Body")
      end
      return doc
    end
  end

end
