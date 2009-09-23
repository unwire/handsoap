# -*- coding: utf-8 -*-
require 'time'
require 'handsoap/xml_mason'
require 'handsoap/xml_query_front'
require 'handsoap/http'

module Handsoap

  def self.http_driver
    @http_driver || (self.http_driver = :curb)
  end

  def self.http_driver=(driver)
    @http_driver = driver
    Handsoap::Http.drivers[driver].load!
    return driver
  end

  def self.xml_query_driver
    @xml_query_driver || (self.xml_query_driver = :nokogiri)
  end

  def self.xml_query_driver=(driver)
    @xml_query_driver = Handsoap::XmlQueryFront.load_driver!(driver)
  end

  class Fault < StandardError
    attr_reader :code, :reason, :details
    def initialize(code, reason, details)
      @code = code
      @reason = reason
      @details = details
    end
    def to_s
      "Handsoap::Fault { :code => '#{@code}', :reason => '#{@reason}' }"
    end
    def self.from_xml(node, options = { :namespace => nil })
      if not options[:namespace]
        raise "Missing option :namespace"
      end
      ns = { 'env' => options[:namespace] }
      fault_code = node.xpath('./env:Code/env:Value', ns).to_s
      unless fault_code
        fault_code = node.xpath('./faultcode', ns).to_s
      end
      reason = node.xpath('./env:Reason/env:Text[1]', ns).to_s
      unless reason
        reason = node.xpath('./faultstring', ns).to_s
      end
      details = node.xpath('./detail/*', ns)
      self.new(fault_code, reason, details)
    end
  end

  class HttpError < StandardError
    attr_reader :response
    def initialize(response)
      @response = response
      super()
    end
  end

  class SoapResponse
    attr_reader :document, :http_response
    def initialize(document, http_response)
      @document = document
      @http_response = http_response
    end
    def method_missing(method, *args)
      if @document.respond_to?(method)
        @document.__send__ method, *args
      else
        super
      end
    end
  end

  class Service
    @@logger = nil
    def self.logger=(io)
      @@logger = io
    end
    # Sets the endpoint for the service.
    # Arguments:
    #   :uri                  => endpoint uri of the service. Required.
    #   :version              => 1 | 2
    #   :envelope_namespace   => Namespace of SOAP-envelope
    #   :request_content_type => Content-Type of HTTP request.
    # You must supply either :version or both :envelope_namspace and :request_content_type.
    # :version is simply a shortcut for default values.
    def self.endpoint(args = {})
      @uri = args[:uri] || raise("Missing option :uri")
      if args[:version]
        soap_namespace = { 1 => 'http://schemas.xmlsoap.org/soap/envelope/', 2 => 'http://www.w3.org/2003/05/soap-envelope' }
        raise("Unknown protocol version '#{@protocol_version.inspect}'") if soap_namespace[args[:version]].nil?
        @envelope_namespace = soap_namespace[args[:version]]
        @request_content_type = args[:version] == 1 ? "text/xml" : "application/soap+xml"
      end
      @envelope_namespace = args[:envelope_namespace] unless args[:envelope_namespace].nil?
      @request_content_type = args[:request_content_type] unless args[:request_content_type].nil?
      if @envelope_namespace.nil? || @request_content_type.nil?
        raise("Missing option :envelope_namespace, :request_content_type or :version")
      end
    end
    def self.envelope_namespace
      @envelope_namespace
    end
    def self.request_content_type
      @request_content_type
    end
    def self.uri
      @uri
    end
    @@instance = {}
    def self.instance
      @@instance[self.to_s] ||= self.new
    end
    def self.method_missing(method, *args)
      if instance.respond_to?(method)
        instance.__send__ method, *args
      else
        super
      end
    end
    def envelope_namespace
      self.class.envelope_namespace
    end
    def request_content_type
      self.class.request_content_type
    end
    def uri
      self.class.uri
    end
    # Creates an XML document and sends it over HTTP.
    #
    # +action+ is the QName of the rootnode of the envelope.
    #
    # +options+ currently takes one option +:soap_action+, which can be one of:
    #
    # :auto sends a SOAPAction http header, deduced from the action name. (This is the default)
    #
    # +String+ sends a SOAPAction http header.
    #
    # +nil+ sends no SOAPAction http header.
    def invoke(action, options = { :soap_action => :auto }, &block) # :yields: Handsoap::XmlMason::Element
      if action
        if options.kind_of? String
          options = { :soap_action => options }
        end
        if options[:soap_action] == :auto
          options[:soap_action] = action.gsub(/^.+:/, "")
        elsif options[:soap_action] == :none
          options[:soap_action] = nil
        end
        doc = make_envelope do |body|
          body.add action
        end
        if block_given?
          yield doc.find(action)
        end
        dispatch(doc, options[:soap_action])
      end
    end
    # Hook that is called when a new request document is created.
    #
    # You can override this to add namespaces and other elements that are common to all requests (Such as authentication).
    def on_create_document(doc)
    end
    # Hook that is called before the message is dispatched.
    #
    # You can override this to provide filtering and logging.
    def on_before_dispatch
    end
    # Hook that is called after the http_client is created.
    #
    # You can override this to customize the http_client
    def on_after_create_http_request(http_request)
    end
    # Hook that is called when there is a response.
    #
    # You can override this to register common namespaces, useful for parsing the document.
    def on_response_document(doc)
    end
    # Hook that is called if there is a HTTP level error.
    #
    # Default behaviour is to raise an error.
    def on_http_error(response)
      raise HttpError, response
    end
    # Hook that is called if the dispatch returns a +Fault+.
    #
    # Default behaviour is to raise the Fault, but you can override this to provide logging and more fine-grained handling faults.
    #
    # See also: parse_soap_fault
    def on_fault(fault)
      raise fault
    end
    # Hook that is called if the response does not contain a valid SOAP enevlope.
    #
    # Default behaviour is to raise an error
    #
    # Note that if your service has operations that are one-way, you shouldn't raise an error here.
    # This is however a fairly exotic case, so that is why the default behaviour is to raise an error.
    def on_missing_document(response)
      raise "The response is not a valid SOAP envelope"
    end
    def debug(message = nil) #:nodoc:
      if @@logger
        if message
          @@logger.puts(message)
        end
        if block_given?
          yield @@logger
        end
      end
    end
    # Does the actual HTTP level interaction.
    def send_http_request(uri, post_body, headers)
      request = Handsoap::Http::Request.new(uri, :post)
      headers.each do |key, value|
        request.add_header(key, value)
      end
      request.body = post_body
      debug do |logger|
        logger.puts request.inspect
      end
      on_after_create_http_request(request)
      http = Handsoap::Http.drivers[Handsoap.http_driver]
      response = http.send_http_request(request)
      debug do |logger|
        logger.puts(response.inspect do |body|
          Handsoap.pretty_format_envelope(body).chomp
        end)
      end
      return response
    end
    # Send document and parses the response into a +XmlQueryFront::XmlElement+ (XmlDocument)
    def dispatch(doc, action)
      on_before_dispatch
      headers = {
        "Content-Type" => "#{self.request_content_type};charset=UTF-8"
      }
      headers["SOAPAction"] = action unless action.nil?
      response = send_http_request(self.uri, doc.to_s, headers)
      # Start the parsing pipe-line.
      # There are various stages and hooks for each, so that you can override those in your service classes.
      xml_document = parse_soap_response_document(response.primary_part.body)
      soap_fault = parse_soap_fault(xml_document)
      # Is the response a soap-fault?
      unless soap_fault.nil?
        return on_fault(soap_fault)
      end
      # Does the http-status indicate an error?
      if response.status >= 400
        return on_http_error(response)
      end
      # Does the response contain a valid xml-document?
      if xml_document.nil?
        return on_missing_document(response)
      end
      # Everything seems in order.
      on_response_document(xml_document)
      return SoapResponse.new(xml_document, response)
    end
    # Creates a standard SOAP envelope and yields the +Body+ element.
    def make_envelope # :yields: Handsoap::XmlMason::Element
      doc = XmlMason::Document.new do |doc|
        doc.alias 'env', self.envelope_namespace
        doc.add "env:Envelope" do |env|
          env.add "*:Header"
          env.add "*:Body"
        end
      end
      self.class.fire_on_create_document doc # deprecated .. use instance method
      on_create_document(doc)
      if block_given?
        yield doc.find("Body")
      end
      return doc
    end
    # String -> [XmlDocument | nil]
    def parse_soap_response_document(http_body)
      begin
        Handsoap::XmlQueryFront.parse_string(http_body, Handsoap.xml_query_driver)
      rescue Handsoap::XmlQueryFront::ParseError => ex
        nil
      end
    end
    # XmlDocument -> [Fault | nil]
    def parse_soap_fault(document)
      unless document.nil?
        node = document.xpath('/env:Envelope/env:Body/descendant-or-self::env:Fault', { 'env' => self.envelope_namespace }).first
        Fault.from_xml(node, :namespace => self.envelope_namespace) unless node.nil?
      end
    end
  end

  def self.pretty_format_envelope(xml_string)
    if /^<.*:Envelope/.match(xml_string)
      begin
        doc = Handsoap::XmlQueryFront.parse_string(xml_string, Handsoap.xml_query_driver)
      rescue
        return xml_string
      end
      return doc.to_xml
      # return "\n\e[1;33m" + doc.to_s + "\e[0m"
    end
    return xml_string
  end
end

# Legacy/BC code here. This shouldn't be used in new applications.
module Handsoap
  class Service
    # Registers a simple method mapping without any arguments and no parsing of response.
    #
    # This is deprecated
    def self.map_method(mapping)
      if @mapping.nil?
        @mapping = {}
      end
      @mapping.merge! mapping
    end
    def self.get_mapping(name)
      @mapping[name] if @mapping
    end
    def method_missing(method, *args)
      action = self.class.get_mapping(method)
      if action
        invoke(action, *args)
      else
        super
      end
    end
    # Registers a block to call when a request document is created.
    #
    # This is deprecated, in favour of #on_create_document
    def self.on_create_document(&block)
      @create_document_callback = block
    end
    def self.fire_on_create_document(doc)
      if @create_document_callback
        @create_document_callback.call doc
      end
    end
    private
    # Helper to serialize a node into a ruby string
    #
    # *deprecated*. Use Handsoap::XmlQueryFront::XmlElement#to_s
    def xml_to_str(node, xquery = nil)
      n = xquery ? node.xpath(xquery, ns).first : node
      return if n.nil?
      n.to_s
    end
    alias_method :xml_to_s, :xml_to_str
    # Helper to serialize a node into a ruby integer
    #
    # *deprecated*. Use Handsoap::XmlQueryFront::XmlElement#to_i
    def xml_to_int(node, xquery = nil)
      n = xquery ? node.xpath(xquery, ns).first : node
      return if n.nil?
      n.to_s.to_i
    end
    alias_method :xml_to_i, :xml_to_int
    # Helper to serialize a node into a ruby float
    #
    # *deprecated*. Use Handsoap::XmlQueryFront::XmlElement#to_f
    def xml_to_float(node, xquery = nil)
      n = xquery ? node.xpath(xquery, ns).first : node
      return if n.nil?
      n.to_s.to_f
    end
    alias_method :xml_to_f, :xml_to_float
    # Helper to serialize a node into a ruby boolean
    #
    # *deprecated*. Use Handsoap::XmlQueryFront::XmlElement#to_boolean
    def xml_to_bool(node, xquery = nil)
      n = xquery ? node.xpath(xquery, ns).first : node
      return if n.nil?
      n.to_s == "true"
    end
    # Helper to serialize a node into a ruby Time object
    #
    # *deprecated*. Use Handsoap::XmlQueryFront::XmlElement#to_date
    def xml_to_date(node, xquery = nil)
      n = xquery ? node.xpath(xquery, ns).first : node
      return if n.nil?
      Time.iso8601(n.to_s)
    end
  end
end
