require 'open-uri'
require 'uri'
require 'cgi'
require 'nokogiri'

# TODO: inline builders, if they are only ever used in one place
# TODO: http://www.crossedconnections.org/w/?p=51 -- The 'typens' namespace is magical ...

class Builders
  def initialize(xsd)
    @xsd = xsd
    @builders = {}
  end
  def add(type)
    @builders[type] = false unless @builders[type]
  end
  def each
    results = []
    while builder = @builders.find { |builder,is_rendered| !is_rendered }
      results << yield(@xsd.get_complex_type(builder[0]))
      @builders[builder[0]] = true
    end
    results.join("")
  end
end

class HandsoapGenerator < Rails::Generator::NamedBase
  attr_reader :wsdl
  def initialize(runtime_args, runtime_options = {})
    super
    # Wsdl argument is required.
    usage if @args.empty?
    @wsdl_uri = @args.shift
  end

  def banner
		"WARNING: This generator is rather incomplete and buggy. Use at your own risk." +
			"\n" + "Usage: #{$0} #{spec.name} name URI [options]" +
      "\n" + "  name  Basename of the service class" +
      "\n" + "  URI   URI of the WSDL to generate from"
  end

  def manifest
    record do |m|
      @wsdl = Handsoap::Wsdl.new(@wsdl_uri)
      @wsdl.parse!
      @xsd = Handsoap::XsdSpider.new(@wsdl_uri)
      @xsd.process!
      m.directory "app"
      m.directory "app/models"
      @builders = Builders.new(@xsd)
      m.template "gateway.rbt", "app/models/#{file_name}_service.rb"
    end
  end

  def builders
    @builders
  end

  def render_build(context_name, message_type, varname = nil, indentation = '    ')
    if varname.nil?
      ruby_name = message_type.ruby_name
    else
      ruby_name = "#{varname}[:#{message_type.ruby_name}]"
    end
    # message_type.namespaces
    if message_type.attribute?
      "#{context_name}.set_attr " + '"' + message_type.name + '", ' + ruby_name
    elsif message_type.boolean?
      "#{context_name}.add " + '"' + message_type.name + '", bool_to_str(' + ruby_name + ')'
    elsif message_type.primitive?
      "#{context_name}.add " + '"' + message_type.name + '", ' + ruby_name
    elsif message_type.list?
      list_type = @xsd.get_complex_type(message_type.type)
      builders.add(list_type.type)
      # TODO: a naming conflict waiting to happen hereabout
      # TODO: indentation
      "#{varname}.each do |#{message_type.ruby_name}|" + "\n" + indentation +
      "  build_#{list_type.ruby_type}!(#{context_name}, #{message_type.ruby_name})" + "\n" + indentation +
      "end"
    else
      builders.add(message_type.type)
      "build_#{message_type.ruby_type}!(#{context_name}, " + ruby_name + ")"
    end
  end

end

module Handsoap

  class Wsdl
    attr_reader :uri, :soap_actions, :soap_ports, :target_namespace
    def initialize(uri)
      @uri = uri
    end

    def parse!
      wsdl = Nokogiri.XML(Kernel.open(@uri).read)
      @target_namespace = wsdl.namespaces['xmlns:tns'] || wsdl.namespaces['xmlns']
      @soap_actions = []
      @soap_ports = []
      messages = {}

      wsdl.xpath('//wsdl:message').each do |message|
        message_name = message['name']
        messages[message_name] = message.xpath('wsdl:part').map { |part| MessageType::Part.new(part['type'] || 'xs:element', part['name']) }
      end

      wsdl.xpath('//*[name()="soap:operation"]').each do |operation|
        operation_name = operation.parent['name']
        operation_spec = wsdl.xpath('//wsdl:operation[@name="' + operation_name + '"]').first
        raise RuntimeError, "Couldn't find wsdl:operation node for #{operation_name}" if operation_spec.nil?
        msg_type_in = operation_spec.xpath('./wsdl:input').first["message"]
        raise RuntimeError, "Couldn't find wsdl:input node for #{operation_name}" if msg_type_in.nil?
        raise RuntimeError, "Invalid message type #{msg_type_in} for #{operation_name}" if messages[msg_type_in].nil?
        msg_type_out = operation_spec.xpath('./wsdl:output').first["message"]
        raise RuntimeError, "Couldn't find wsdl:output node for #{operation_name}" if msg_type_out.nil?
        raise RuntimeError, "Invalid message type #{msg_type_out} for #{operation_name}" if messages[msg_type_out].nil?
        @soap_actions << SoapAction.new(operation, messages[msg_type_in], messages[msg_type_out])
      end
      raise RuntimeError, "Could not parse WSDL" if soap_actions.empty?

      wsdl.xpath('//wsdl:port', {"xmlns:wsdl" => 'http://schemas.xmlsoap.org/wsdl/'}).each do |port|
        name = port['name'].underscore
        location = port.xpath('./*[@location]').first['location']
        @soap_ports << { :name => name, :soap_name => port['name'], :location => location }
      end
    end
  end

  class SoapAction
    attr_reader :input_type, :output_type
    def initialize(xml_node, input_type, output_type)
      @xml_node = xml_node
      @input_type = input_type
      @output_type = output_type
    end
    def name
      @xml_node.parent['name'].underscore
    end
    def soap_name
      @xml_node.parent['name']
    end
    def href
      @xml_node['soapAction']
    end
  end

  module MessageType

    # complex-type is a spec (class), not an element ... (object)
    # <xs:complexType name="User">
		#   <xs:annotation>
    #     <xs:documentation>The element specifies a user</xs:documentation>
    #   </xs:annotation>
    #   <xs:attribute name="dn" type="xs:string" use="required"/>
    # </xs:complexType>
    class ComplexType
      def initialize(xml_node)
        @xml_node = xml_node
      end
      def type
        @xml_node['name']
      end
      def ruby_type
        type.gsub(/^.*:/, "").underscore.gsub(/-/, '_')
      end
      def elements
        @xml_node.xpath('./xs:attribute|./xs:all/xs:element|./xs:sequence').map do |node|
          case
            when node.node_name == 'attribute'
            Attribute.new(node['type'], node['name'])
            when node.node_name == 'element'
            Element.new(node['type'], node['name'], []) # TODO: elements.elements
            when node.node_name == 'sequence'
            choice_node = node.xpath('./xs:choice').first
            if choice_node
              # TODO
              Attribute.new('xs:choice', 'todo')
            else
              entity_node = node.xpath('./xs:element').first
              Sequence.new(entity_node['type'], entity_node['name'])
            end
          else
            puts node
            raise "Unknown type #{node.node_name}"
          end
        end
      end
    end

    class Base
      attr_reader :type, :name
      def initialize(type, name)
        raise "'type' can't be nil" if type.nil?
        raise "'name' can't be nil" if name.nil?
        @type = type
        @name = name
      end
      def ruby_type
        type.gsub(/^.*:/, "").underscore.gsub(/-/, '_')
      end
      def ruby_name
        name.underscore.gsub(/-/, '_')
      end
      def attribute?
        false
      end
      def primitive?
        /^xs:/.match type
      end
      def boolean?
        type == "xs:boolean"
      end
      def list?
        false
      end
    end

    # Parts are shallow elements
    # <wsdl:part name="widget-instance-id" type="xs:int" />
    class Part < Base
    end

    # <wsdl:part name="widget-instance-id" type="xs:int" />
    # <xs:element maxOccurs="1" minOccurs="0" name="description" type="xs:string"/>
    class Element < Base
      attr_reader :elements
      def initialize(type, name, elements = [])
        super(type, name)
        @elements = elements
      end
    end

    # <xs:attribute name="id" type="xs:int" use="required"/>
    class Attribute < Base
      def primitive?
        true
      end
      def attribute?
        true
      end
    end

    # <xs:sequence>
	  #   <xs:element maxOccurs="unbounded" minOccurs="0" name="widget-area" type="WidgetArea"/>
	  # </xs:sequence>
    class Sequence < Base
      def list?
        true
      end
    end
  end
end

module Handsoap

  class XsdSpider
    def initialize(uri)
      @queue = []
      @wsdl_uri = uri
    end

    def results
      @queue.map { |element| element[:data] }
    end

    def get_complex_type(name)
      # TODO namespace
      short_name = name.gsub(/^.*:/, "")
      results.each do |data|
        search = data[:document].xpath('//xs:complexType[@name="' + short_name + '"]')
        if search.any?
          return MessageType::ComplexType.new(search.first)
        end
      end
      raise "Didn't find '#{name}' (short name #{short_name})"
    end

    def process!
      spider_href(@wsdl_uri, nil)
      while process_next do end
    end

    private

    def add_href(href, namespace)
      unless @queue.find { |element| element[:href] == href }
        @queue << { :href => href, :namespace => namespace, :state => :new, :data => {} }
      end
    end

    def process_next
      next_element = @queue.find { |element| element[:state] == :new }
      if next_element
        next_element[:data] = spider_href(next_element[:href], next_element[:namespace])
        next_element[:state] = :done
        return true
      end
      return false
    end

    def spider_href(href, namespace)
      raise "'href' must be a String" if href.nil?
      xsd = Nokogiri.XML(Kernel.open(href).read)
      # <xs:include schemaLocation="...xsd"/>
      # <xs:import namespace="" schemaLocation="...xsd"/>
      xsd.xpath('//*[@schemaLocation]').each do |inc|
        add_href(inc['schemaLocation'], inc['namespace'] || namespace)
      end
      { :document => xsd, :namespace => namespace }
    end
  end
end
