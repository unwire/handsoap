# -*- coding: utf-8 -*-
require 'rubygems'
require 'httpclient'
require 'nokogiri'
require 'curb'
require 'handsoap/xml_mason'

module Handsoap

  def self.http_driver
    @http_driver || :curb
  end

  def self.http_driver=(driver)
    @http_driver = driver
  end

  SOAP_NAMESPACE = { 1 => 'http://schemas.xmlsoap.org/soap/envelope/', 2 => 'http://www.w3.org/2001/12/soap-encoding' }

  class Response
    def initialize(http_body, soap_namespace)
      @http_body = http_body
      @soap_namespace = soap_namespace
      @document = :lazy
      @fault = :lazy
    end
    def document?
      !! document
    end
    def document
      if @document == :lazy
        doc = Nokogiri::XML(@http_body)
        @document = (doc && doc.root && doc.errors.empty?) ? doc : nil
      end
      return @document
    end
    def fault?
      !! fault
    end
    def fault
      if @fault == :lazy
        nodes = document? ? document.xpath('/env:Envelope/env:Body/env:Fault', { 'env' => @soap_namespace }) : []
        @fault = nodes.any? ? Fault.from_xml(nodes.first, :namespace => @soap_namespace) : nil
      end
      return @fault
    end
  end

  class Fault < Exception
    attr_reader :code, :reason
    def initialize(code, reason)
      @code = code
      @reason = reason
    end
    def to_s
      "Handsoap::Fault { :code => '#{@code}', :reason => '#{@reason}' }"
    end
    def self.from_xml(node, options = { :namespace => nil })
      if not options[:namespace]
        raise "Missing option :namespace"
      end
      ns = { 'env' => options[:namespace] }
      fault_code = node.xpath('./env:Code/env:Value/text()', ns).to_s
      if fault_code == ""
        fault_code = node.xpath('./faultcode/text()', ns).to_s
      end
      reason = node.xpath('./env:Reason/env:Text[1]/text()', ns).to_s
      if reason == ""
        reason = node.xpath('./faultstring/text()', ns).to_s
      end
      self.new(fault_code, reason)
    end
  end

  class Service
    @@logger = nil
    def self.logger=(io)
      @@logger = io
    end
    def self.endpoint(args = {})
      @protocol_version = args[:version] || raise("Missing option :version")
      @uri = args[:uri] || raise("Missing option :uri")
    end
    def self.envelope_namespace
      if SOAP_NAMESPACE[@protocol_version].nil?
        raise "Unknown protocol version '#{@protocol_version.inspect}'"
      end
      SOAP_NAMESPACE[@protocol_version]
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
    def self.uri
      @uri
    end
    def self.get_mapping(name)
      @mapping[name] if @mapping
    end
    def self.instance
      @@instance ||= self.new
    end
    def self.method_missing(method, *args)
      if instance.respond_to?(method)
        instance.__send__ method, *args
      else
        super
      end
    end
    def method_missing(method, *args)
      action = self.class.get_mapping(method)
      if action
        invoke(action, *args)
      else
        super
      end
    end
    def invoke(action, &block)
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
    def debug(message = nil)
      if @@logger
        if message
          @@logger.puts(message)
        end
        if block_given?
          yield @@logger
        end
      end
    end
    def dispatch(doc)
      headers = {
        "Content-Type" => "text/xml;charset=UTF-8"
      }
      body = doc.to_s
      debug do |logger|
        logger.puts "==============="
        logger.puts "--- Request ---"
        logger.puts "URI: %s" % [self.class.uri]
        logger.puts headers.map { |key,value| key + ": " + value }.join("\n")
        logger.puts "---"
        logger.puts body
      end
      if Handsoap.http_driver == :curb
        http_client = Curl::Easy.new(self.class.uri)
        http_client.headers = headers
        http_client.http_post body
        debug do |logger|
          logger.puts "--- Response ---"
          logger.puts "HTTP Status: %s" % [http_client.response_code]
          logger.puts "Content-Type: %s" % [http_client.content_type]
          logger.puts "---"
          logger.puts Handsoap.pretty_format_envelope(http_client.body_str)
        end
        soap_response = Response.new(http_client.body_str, self.class.envelope_namespace)
      else
        response = HTTPClient.new.post(self.class.uri, body, headers)
        debug do |logger|
          logger.puts "--- Response ---"
          logger.puts "HTTP Status: %s" % [response.status]
          logger.puts "Content-Type: %s" % [response.contenttype]
          logger.puts "---"
          logger.puts Handsoap.pretty_format_envelope(response.content)
        end
        soap_response = Response.new(response.content, self.class.envelope_namespace)
      end
      if soap_response.fault?
        raise soap_response.fault
      end
      return soap_response
    end
    def make_envelope
      doc = XmlMason::Document.new do |doc|
        doc.alias 'env', self.class.envelope_namespace
        doc.add "env:Envelope" do |env|
          env.add "*:Header"
          env.add "*:Body"
        end
      end
      self.class.fire_on_create_document doc
      if block_given?
        yield doc.find("Body")
      end
      return doc
    end
  end

  def self.pretty_format_envelope(xml_string)
    if /^<.*:Envelope.*<\/.*:Envelope>$/.match(xml_string)
      begin
        doc = Nokogiri::XML(xml_string)
      rescue Exception => ex
        return "Formatting failed: " + ex.to_s
      end
      return doc.to_s
      # return "\n\e[1;33m" + doc.to_s + "\e[0m"
    end
    return xml_string
  end

end
