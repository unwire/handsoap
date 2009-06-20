# -*- coding: utf-8 -*-
module Handsoap
  #
  # A simple frontend for parsing XML document with Xpath.
  #
  # This provides a unified interface for multiple xpath-capable dom-parsers,
  # allowing seamless switching between the underlying implementations.
  #
  # A document is loaded using the function Handsoap::XmlQueryFront.parse_string, passing
  # the xml source string and a driver, which can (currently) be one of:
  #
  #   :rexml
  #   :nokogiri
  #   :libxml
  #
  # The resulting object is a wrapper, of the type Handsoap::XmlQueryFront::BaseDriver.
  #
  module XmlQueryFront

    # This error is raised if the document didn't parse
    class ParseError < RuntimeError; end

    # Loads requirements for a driver.
    #
    # This function is implicitly called by +parse_string+.
    def self.load_driver!(driver)
      if driver == :rexml
        require 'rexml/document'
      elsif driver == :nokogiri
        require 'nokogiri'
      elsif driver == :libxml
        require 'libxml'
      else
        raise "Unknown driver #{driver}"
      end
      return driver
    end

    # Returns a wrapped XML parser, using the requested driver.
    #
    # +driver+ can be one of the following:
    #   :rexml
    #   :nokogiri
    #   :libxml
    def self.parse_string(xml_string, driver)
      load_driver!(driver)
      if driver == :rexml
        doc = REXML::Document.new(xml_string)
        raise ParseError.new if doc.root.nil?
        XmlQueryFront::REXMLDriver.new(doc)
      elsif driver == :nokogiri
        doc = Nokogiri::XML(xml_string)
        raise ParseError.new unless (doc && doc.root && doc.errors.empty?)
        XmlQueryFront::NokogiriDriver.new(doc)
      elsif driver == :libxml
        begin
          LibXML::XML::Error.set_handler &LibXML::XML::Error::QUIET_HANDLER
          doc = XmlQueryFront::LibXMLDriver.new(LibXML::XML::Parser.string(xml_string).parse)
        rescue ArgumentError, LibXML::XML::Error => ex
          raise ParseError.new
        end
      end
    end

    # Wraps the underlying (native) xml driver, and provides a uniform interface.
    module BaseDriver
      def initialize(element, namespaces = {})
        @element = element
        @namespaces = namespaces
      end
      # Registers a prefix to refer to a namespace.
      #
      # You can either register a nemspace with this function or pass it explicitly to the +xpath+ method.
      def add_namespace(prefix, uri)
        @namespaces[prefix] = uri
      end
      # Checks that an xpath-query doesn't refer to any undefined prefixes in +ns+
      def assert_prefixes!(expression, ns)
        expression.scan(/([a-zA-Z_][a-zA-Z0-9_.-]*):/).map{|m| m[0] }.each do |prefix|
          raise "Undefined prefix '#{prefix}'" if ns[prefix].nil?
        end
      end
      # Returns the value of the element as an integer.
      #
      # See +to_s+
      def to_i
        t = self.to_s
        return if t.nil?
        t.to_i
      end
      # Returns the value of the element as a float.
      #
      # See +to_s+
      def to_f
        t = self.to_s
        return if t.nil?
        t.to_f
      end
      # Returns the value of the element as an boolean.
      #
      # See +to_s+
      def to_boolean
        t = self.to_s
        return if t.nil?
        t.downcase == 'true'
      end
      # Returns the value of the element as a ruby Time object.
      #
      # See +to_s+
      def to_date
        t = self.to_s
        return if t.nil?
        Time.iso8601(t)
      end
      # Returns the underlying native element.
      #
      # You shouldn't need to use this, since doing so would void portability.
      def native_element
        @element
      end
      # Returns the node name of the current element.
      def node_name
        raise NotImplementedError.new
      end
      # Queries the document with XPath, relative to the current element.
      #
      # +ns+ Should be a Hash of prefix => namespace
      #
      # Returns an Array of wrapped elements.
      #
      # See add_namespace
      def xpath(expression, ns = nil)
        raise NotImplementedError.new
      end
      # Returns the inner text content of this element, or the value (if it's an attr or textnode).
      #
      # The output is a UTF-8 encoded string, without xml-entities.
      def to_s
        raise NotImplementedError.new
      end
      # Returns the outer XML for this element.
      def to_xml
        raise NotImplementedError.new
      end
      # Alias for +xpath+
      def /(expression)
        self.xpath(expression)
      end
    end

    # Driver for +libxml+.
    #
    # http://libxml.rubyforge.org/
    class LibXMLDriver
      include BaseDriver
      def node_name
        @element.name
      end
      def xpath(expression, ns = nil)
        ns = {} if ns.nil?
        ns = @namespaces.merge(ns)
        assert_prefixes!(expression, ns)
        @element.find(expression, ns.map{|k,v| "#{k}:#{v}" }).to_a.map{|node| LibXMLDriver.new(node, ns) }
      end
      def to_xml
        @element.to_s
      end
      def to_s
        if @element.kind_of? LibXML::XML::Attr
          @element.value
        else
          @element.content
        end
      end
    end

    # Driver for +REXML+
    #
    # http://www.germane-software.com/software/rexml/
    class REXMLDriver
      include BaseDriver
      def node_name
        @element.name
      end
      def xpath(expression, ns = nil)
        ns = {} if ns.nil?
        ns = @namespaces.merge(ns)
        assert_prefixes!(expression, ns)
        REXML::XPath.match(@element, expression, ns).map{|node| REXMLDriver.new(node, ns) }
      end
      def to_xml
        require 'rexml/formatters/pretty'
        formatter = REXML::Formatters::Pretty.new
        out = String.new
        formatter.write(@element, out)
        out
      end
      def to_s
        if @element.kind_of? REXML::Attribute
          @element.value
        else
          @element.text
        end
      end
    end

    # Driver for +Nokogiri+
    #
    # http://nokogiri.rubyforge.org/nokogiri/
    class NokogiriDriver
      include BaseDriver
      def node_name
        @element.name
      end
      def self.serialize_args # :nodoc
        @serialize_args ||= if Gem.loaded_specs['nokogiri'].version >= Gem::Version.new('1.3.0')
                              { :encoding => 'UTF-8' }
                            else
                              'UTF-8'
                            end
      end
      def xpath(expression, ns = nil)
        ns = {} if ns.nil?
        ns = @namespaces.merge(ns)
        assert_prefixes!(expression, ns)
        @element.xpath(expression, ns).map{|node| NokogiriDriver.new(node, ns) }
      end
      def to_xml
        @element.serialize(NokogiriDriver.serialize_args)
      end
      def to_s
        if @element.kind_of?(Nokogiri::XML::Text) || @element.kind_of?(Nokogiri::XML::CDATA)
          element = @element
        elsif @element.kind_of?(Nokogiri::XML::Attr)
          return @element.value
        else
          element = @element.children.first
        end
        return if element.nil?
        # This looks messy because it is .. Nokogiri's interface is in a flux
        if element.kind_of?(Nokogiri::XML::CDATA)
          element.serialize(NokogiriDriver.serialize_args).gsub(/^<!\[CDATA\[/, "").gsub(/\]\]>$/, "")
        else
          element.serialize(NokogiriDriver.serialize_args).gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&apos;', "'").gsub('&amp;', '&')
        end
      end
    end
  end
end
