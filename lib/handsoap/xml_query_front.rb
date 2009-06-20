# -*- coding: utf-8 -*-
#
# A simple frontend for parsing XML document with Xpath.
#
# This provides a unified interface for multiple xpath-capable dom-parsers,
# allowing seamless switching between the underlying implementations.
module Handsoap
  module XmlQueryFront
    # Returns a wrapped XML parser, using the requested driver
    def self.parse_string(xml_string, driver = :rexml)
      if driver == :rexml
        require 'rexml/document'
        XmlQueryFront::REXMLDriver.new(REXML::Document.new(xml_string))
      elsif driver == :nokogiri
        require 'nokogiri'
        XmlQueryFront::NokogiriDriver.new(Nokogiri::XML(xml_string))
      elsif driver == :libxml
        require 'libxml'
        XmlQueryFront::LibXMLDriver.new(LibXML::XML::Parser.string(xml_string).parse)
      else
        raise "Unknown driver #{driver}"
      end
    end
    module BaseDriver
      def initialize(element, namespaces = {})
        @element = element
        @namespaces = namespaces
      end
      def add_namespace(prefix, uri)
        @namespaces[prefix] = uri
      end
      def assert_prefixes!(expression, ns)
        expression.scan(/([a-zA-Z_][a-zA-Z0-9_.-]*):/).map{|m| m[0] }.each do |prefix|
          raise "Undefined prefix '#{prefix}'" if ns[prefix].nil?
        end
      end
      def to_i
        t = self.to_s
        return if t.nil?
        t.to_i
      end
      def to_f
        t = self.to_s
        return if t.nil?
        t.to_f
      end
      def to_boolean
        t = self.to_s
        return if t.nil?
        t.downcase == 'true'
      end
      def to_date
        t = self.to_s
        return if t.nil?
        Time.iso8601(t)
      end
      def native_element
        @element
      end
      def /(expression)
        self.xpath(expression)
      end
    end
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
      def to_s
        if @element.kind_of? LibXML::XML::Attr
          @element.value
        else
          @element.content
        end
      end
    end
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
      # Returns the inner content of this element, or the value (if it's an attr or textnode) as UTF-8.
      def to_s
        if @element.kind_of? REXML::Attribute
          @element.value
        else
          @element.text
        end
      end
    end
    class NokogiriDriver
      include BaseDriver
      def node_name
        @element.name
      end
      def self.serialize_args
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
      # Returns the inner content of this element, or the value (if it's an attr or textnode) as UTF-8.
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
