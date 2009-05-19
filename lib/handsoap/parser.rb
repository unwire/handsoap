# -*- coding: utf-8 -*-
require 'open-uri'
require 'nokogiri'

module Handsoap

  module Parser

    class XsdSpider
      def initialize(uri)
        @queue = []
        @wsdl_uri = uri
      end

      def results
        @queue
      end

      def wsdl
        @queue.each do |element|
          return element if element[:href] == @wsdl_uri
        end
      end

      def process!
        add_href @wsdl_uri
        while process_next do end
      end

      private

      def add_href(href, namespaces = {})
        unless @queue.find { |element| element[:href] == href }
          @queue << { :href => href, :namespaces => namespaces, :state => :new, :document => nil }
        end
      end

      def process_next
        next_element = @queue.find { |element| element[:state] == :new }
        if next_element
          next_element.merge! spider_href(next_element[:href], next_element[:namespaces])
          next_element[:state] = :done
          return true
        end
        return false
      end

      def spider_href(href, namespaces)
        raise "'href' must be a String" if href.nil?
        # puts "getting #{href}"
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        xsd = Nokogiri.XML(Kernel.open(href).read)
        namespaces.merge! xsd.namespaces
        # <xs:include schemaLocation="...xsd"/>
        # <xs:import namespace="" schemaLocation="...xsd"/>
        xsd.xpath('//xs:include', ns_xs).each do |inc|
          add_href(inc['schemaLocation'], namespaces)
        end
        xsd.xpath('//xs:import', ns_xs).each do |inc|
          add_href(inc['schemaLocation'], namespaces.merge({ 'xmlns' => inc['namespace'] }))
        end
        { :document => xsd, :namespaces => namespaces }
      end
    end

    class QName
      attr_reader :name, :namespace
      def initialize(str_repr, namespaces)
        @str_repr = str_repr.to_s
        matches = /^(.+):(.+)$/.match(str_repr)
        if matches
          @name = matches[2]
          @namespace = namespaces['xmlns:' + matches[1]] || raise("Document doesn't define namespace '#{matches[1]}'")
        else
          @name = str_repr
          @namespace = namespaces['xmlns']
        end
      end
      def full_name
        "{#{@namespace}}#{@name}"
      end
      def to_s
        # @str_repr
        full_name
      end
    end

    class WSDL
      def initialize(xsd)
        @xsd = xsd
      end

      def namespaces
        @xsd.wsdl[:document].collect_namespaces
      end

      def messages
        # <message name="KeywordSearchRequest">
        #   <part name="KeywordSearchRequest" type="typens:KeywordRequest"/>
        # ---
        # {
        #   'KeywordSearchRequest' => {
        #     'KeywordSearchRequest' => Part(
        #       :name => '..',
        #       :type => QName('typens:KeywordRequest')
        #     )
        #   }
        # }
        return @messages if @messages
        ns_wsdl = {'wsdl' => 'http://schemas.xmlsoap.org/wsdl/'}
        wsdl = @xsd.wsdl[:document]
        @messages = {}
        wsdl.xpath('//wsdl:message', ns_wsdl).each do |xml_message|
          name = xml_message['name']
          @messages[name] = []
          xml_message.xpath('./wsdl:part', ns_wsdl).each do |xml_part|
            @messages[name] << Part.new(xml_part['name'], QName.new(xml_part['type'] || xml_part['element'], wsdl.namespaces))
          end
        end
        return @messages
      end

      def port_types
        # <portType name="AmazonSearchPort">
        #   <operation name="KeywordSearchRequest">
        #     <input message="typens:KeywordSearchRequest"/>
        #     <output message="typens:KeywordSearchResponse"/>
        # --
        # {
        #   'AmazonSearchPort' => {
        #     'KeywordSearchRequest' => {
        #       'input' => MessageType(
        #         :name => 'input',
        #         :message => QName('typens:KeywordSearchRequest')
        #       ),
        #       'output' => MessageType(
        #         :name => 'output',
        #         :message => QName('typens:KeywordSearchResponse')
        #       )
        #     }
        #   }
        # }
        return @port_types if @port_types
        ns_wsdl = {'wsdl' => 'http://schemas.xmlsoap.org/wsdl/'}
        wsdl = @xsd.wsdl[:document]
        @port_types = {}
        wsdl.xpath('//wsdl:portType', ns_wsdl).each do |xml_port_type|
          port_type_name = xml_port_type['name']
          operations = {}
          xml_port_type.xpath('./wsdl:operation', ns_wsdl).each do |xml_operation|
            operations[xml_operation['name']] = {}
            xml_operation.xpath('./wsdl:*[@message]', ns_wsdl).each do |xml_message_type|
              message_type = MessageType.new(xml_message_type.node_name, QName.new(xml_message_type['message'], wsdl.namespaces))
              operations[xml_operation['name']][message_type.name] = message_type
            end
          end
          @port_types[port_type_name] = operations
        end
        return @port_types
      end

      def bindings
        # <binding name="AmazonSearchBinding" type="typens:AmazonSearchPort">
        #   <soap:binding style="rpc" transport="http://schemas.xmlsoap.org/soap/http"/>
        #   <operation name="KeywordSearchRequest">
        #     <soap:operation soapAction="http://soap.amazon.com"/>
        #     <input>
        #       <soap:body use="encoded" encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" namespace="http://soap.amazon.com"/>
        #     <output>
        #       <soap:body use="encoded" encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" namespace="http://soap.amazon.com"/>
        # --
        # {
        #   'AmazonSearchBinding' => Binding(
        #     :name => 'AmazonSearchBinding',
        #     :type => QName('typens:AmazonSearchPort'),
        #     :style => 'rpc',
        #     :transport => 'http://schemas.xmlsoap.org/soap/http',
        #     :operations => {
        #       'KeywordSearchRequest' => Operation(
        #         :soap_action => 'http://soap.amazon.com',
        #         :messages => {
        #           'input' => {
        #             'body' => Section(
        #               :use => 'encoded',
        #               :encoding_style => 'http://schemas.xmlsoap.org/soap/encoding/',
        #               :namespace => 'http://soap.amazon.com'
        #             ),
        #           },
        #           'output' => {
        #             'body' => Section(
        #               :use => 'encoded',
        #               :encoding_style => 'http://schemas.xmlsoap.org/soap/encoding/',
        #               :namespace => 'http://soap.amazon.com'
        #             )
        #           }
        #         }
        #       )
        #     }
        #   )
        # }
        return @bindings if @bindings
        ns_wsdl = {'wsdl' => 'http://schemas.xmlsoap.org/wsdl/'}
        ns_soap1 = {'soap' => 'http://schemas.xmlsoap.org/wsdl/soap/'}
        ns_soap2 = {'soap' => 'http://schemas.xmlsoap.org/wsdl/soap12/'}
        ns_soap_http = {'soap' => 'http://schemas.xmlsoap.org/wsdl/http/'}
        ns_soap = nil
        wsdl = @xsd.wsdl[:document]
        @bindings = {}
        wsdl.xpath('//wsdl:binding', ns_wsdl).each do |xml_wsdl_binding|
          ns_soap = ns_soap1
          soap_version = 1
          xml_soap_binding = xml_wsdl_binding.xpath('./soap:binding', ns_soap).first
          unless xml_soap_binding
            ns_soap = ns_soap2
            soap_version = 2
            xml_soap_binding = xml_wsdl_binding.xpath('./soap:binding', ns_soap).first
          end
          # p xml_wsdl_binding if not xml_soap_binding
          # raise "Expected <soap:binding>" if not xml_soap_binding
          if xml_soap_binding
            binding = Binding.new(
                                  xml_wsdl_binding['name'],
                                  QName.new(xml_wsdl_binding['type'], wsdl.namespaces),
                                  soap_version,
                                  xml_soap_binding['style'],
                                  xml_soap_binding['transport'])
            @bindings[binding.name] = binding
            xml_wsdl_binding.xpath('./wsdl:operation', ns_wsdl).each do |xml_wsdl_operation|
              xml_soap_operation = xml_wsdl_operation.xpath('./soap:operation', ns_soap).first
              raise "Expected <soap:operation>" if not xml_soap_operation
              operation = Operation.new(
                                        xml_wsdl_operation['name'],
                                        xml_soap_operation['soapAction'])
              binding.operations[xml_wsdl_operation['name']] = operation
              xml_wsdl_operation.xpath('./wsdl:*', ns_wsdl).each do |xml_wsdl_message|
                sections = {}
                xml_wsdl_message.xpath('./soap:*', ns_soap).each do |xml_soap_section|
                  sections[xml_soap_section.node_name] = Section.new(
                                                                     xml_soap_section.node_name,
                                                                     xml_soap_section['use'],
                                                                     xml_soap_section['encodingStyle'],
                                                                     xml_soap_section['namespace'])
                end
                operation.messages[xml_wsdl_message.node_name] = sections
              end
            end
          else
            puts "Skipping unknown binding"
            # Skipping unknown binding ...
          end
        end
        return @bindings
      end

      def services
        # <service name="AmazonSearchService">
        #   <port name="AmazonSearchPort" binding="typens:AmazonSearchBinding">
        #     <soap:address location="http://soap.amazon.com/onca/soap2"/>
        # ---
        # {
        #   'AmazonSearchService' => {
        #     'AmazonSearchPort' => Port(
        #       :name => 'AmazonSearchPort',
        #       :binding => QName('typens:AmazonSearchBinding'),
        #       :location => 'http://soap.amazon.com/onca/soap2'
        #     )
        #   }
        # }
        return @services if @services
        ns_wsdl = {'wsdl' => 'http://schemas.xmlsoap.org/wsdl/'}
        ns_soap = {'soap' => 'http://schemas.xmlsoap.org/wsdl/soap/'}
        wsdl = @xsd.wsdl[:document]
        @services = {}
        wsdl.xpath('//wsdl:service', ns_wsdl).each do |xml_wsdl_service|
          service_name = xml_wsdl_service['name']
          @services[service_name] = {}
          xml_wsdl_service.xpath('./wsdl:port', ns_wsdl).each do |xml_wsdl_port|
            xml_soap_address = xml_wsdl_port.xpath('./soap:address', ns_soap).first
            raise "Expected <soap:address>" if not xml_soap_address
            @services[service_name][xml_wsdl_port['name']] = Port.new(
                                                                     xml_wsdl_port['name'],
                                                                     QName.new(xml_wsdl_port['binding'], wsdl.namespaces),
                                                                     xml_soap_address['location'])
          end
        end
        return @services
      end

      def elements
        # <xs:schema version="1.0" targetNamespace="http://namesservice.thomas_bayer.com/">
        #   <xs:element name="getCountries" type="tns:getCountries"/>
        # ---
        # {
        #   '{http://namesservice.thomas_bayer.com/}getCountries' => Element(
        #     :name => 'getCountries',
        #     :type => QName('tns:getCountries')
        #   )
        # }
        return @elements if @elements
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        @elements = {}
        @xsd.results.each do |loaded_document|
          document = loaded_document[:document]
          namespaces = loaded_document[:namespaces]
          document.xpath('//xs:schema', ns_xs).each do |xml_schema|
            xml_schema.xpath('./xs:element', ns_xs).each do |xml_element|
              element = parse_element(xml_element, namespaces)
              @elements[element.name.full_name] = element unless element.substitution_group
            end
          end
        end
        return @elements
      end

      def types
        # <wsdl:types>
        #   <xsd:schema targetNamespace="http://soap.amazon.com">
        #     <xsd:complexType name="ProductLineArray"/>
        # ---
        # {
        #   '{http://soap.amazon.com}ProductLineArray' => ComplexType(
        #     :name => QName('tns:ProductLineArray'),
        #     ...
        #   ),
        # }
        return @types if @types
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        @types = {}
        @xsd.results.each do |loaded_document|
          document = loaded_document[:document]
          namespaces = loaded_document[:namespaces]
          document.xpath('//xs:schema', ns_xs).each do |xml_schema|
            namespaces.merge!({'xmlns' => xml_schema['targetNamespace'] }) if xml_schema['targetNamespace']
            xml_schema.xpath('./xs:complexType|xs:simpleType', ns_xs).each do |xml_typedef|
              typedef = parse_typedef(xml_typedef, namespaces)
              @types[typedef.name.full_name] = typedef
            end
          end
        end
        return @types
      end

      def groups
        # <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        #   <xs:group name="custGroup">
        #     ...
        # ---
        # {
        #   'custGroup' => ElementGroup(
        #     :name => QName('tns:custGroup'),
        #     :structure => ...
        #   ),
        # }
        return @groups if @groups
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        @groups = {}
        @xsd.results.each do |loaded_document|
          document = loaded_document[:document]
          namespaces = loaded_document[:namespaces]
          document.xpath('//xs:schema', ns_xs).each do |xml_schema|
            xml_schema.xpath('./xs:group', ns_xs).each do |xml_group|
              group = parse_element_structure(xml_group, namespaces)
              @groups[group.name.full_name] = group
            end
          end
        end
        return @groups
      end

      def attribute_groups
        # <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        #   <xs:attributeGroup name="personattr">
        #     <xs:attribute name="attr1" type="string"/>
        # ---
        # {
        #   'personattr' => AttributeGroup(
        #     :name => QName('tns:personattr'),
        #     :attributes => [
        #       Attribute(
        #         :name => 'attr1',
        #         :type => QName('tns:string')
        #       )
        #     ]
        #   )
        # }
        return @attribute_groups if @attribute_groups
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        @attribute_groups = {}
        @xsd.results.each do |loaded_document|
          document = loaded_document[:document]
          namespaces = loaded_document[:namespaces]
          document.xpath('//xs:schema', ns_xs).each do |xml_schema|
            xml_schema.xpath('./xs:attributeGroup', ns_xs).each do |xml_attribute_group|
              attribute_group = parse_attribute_group(xml_attribute_group, namespaces)
              @attribute_groups[attribute_group.name.full_name] = attribute_group
            end
          end
        end
        return @attribute_groups
      end

      def attributes
        # <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        #   <xs:attribute name="attr1" type="string"/>
        # ---
        # {
        #   'attr1' => Attribute(
        #     :name => 'attr1',
        #     :type => QName('tns:string')
        #   )
        # }
        return @attributes if @attributes
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        @attributes = {}
        @xsd.results.each do |loaded_document|
          document = loaded_document[:document]
          namespaces = loaded_document[:namespaces]
          document.xpath('//xs:schema', ns_xs).each do |xml_schema|
            xml_schema.xpath('./xs:attribute', ns_xs).each do |xml_attribute|
              attribute = parse_attribute(xml_attribute, namespaces)
              @attributes[attributes.name.full_name] = attribute
            end
          end
        end
        return @attributes
      end

      def parse_element(xml_element, namespaces)
        if xml_element['substitutionGroup']
          raise "TODO: xs:substitutionGroup not supported"
        end
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        # An element might contain a complexType definition.
        #   http://www.w3schools.com/Schema/schema_complex.asp
        xml_typedef = xml_element.xpath('./xs:complexType|xs:simpleType', ns_xs).first
        if xml_typedef
          typedef = parse_typedef(xml_typedef, namespaces)
        else
          typedef = nil
        end
        Element.new(
                    QName.new(xml_element['name'], namespaces),
                    xml_element['type'] ? QName.new(xml_element['type'], namespaces) : nil,
                    typedef,
                    xml_element['default'],
                    xml_element['fixed'],
                    xml_element['substitutionGroup'])
        # TODO: Elements may have restrictions.
        # http://www.w3schools.com/Schema/schema_facets.asp
      end

      def parse_typedef(xml_typedef, namespaces)
        if xml_typedef.node_name == 'simpleType'
          parse_simple_type(xml_typedef, namespaces)
        else
          parse_complex_type(xml_typedef, namespaces)
        end
      end

      def parse_complex_type(xml_typedef, namespaces)
        # Let's settle the ground-rules, shall we?
        # The contents of an xs:complexType are as follows:
        # .. these are really just modifiers to the xs:complexType node
        # xs:complexContent
        # xs:simpleContent
        # .. Just an attribute (may refer to an attribute or define it)
        # xs:attribute
        # .. element qualifiers - this is the real meat
        # xs:sequence
        # xs:all
        # xs:choice
        # .. can occur within one of the above
        # xs:element
        # .. groups are like mixins (may refer to a group or define it)
        # xs:group
        # xs:attributeGroup
        # .. who the #¤%& was the genius who thought that it would be a good idea to spend pages upon pages of
        # .. defining an immensely complex type system, and then add a loop-hole that basically allows anyone
        # .. to just crap all over it? Seriously!
        # xs:any (xsd-cop-out .. allows anything)
        # xs:anyAttribute (xsd-cop-out .. allows anything)
        #
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        name = xml_typedef['name'] ? QName.new(xml_typedef['name'], namespaces) : nil
        base = nil
        inheritance_style = nil
        content_style = nil
        element_structure = nil
        xml_content = xml_typedef.xpath('./xs:complexContent|xs:simpleContent', ns_xs).first
        if xml_content
          content_style = xml_content.node_name == 'complexContent' ? :complex : :simple
          xml_annotation = xml_content.xpath('./xs:extension|xs:restriction', ns_xs).first
          raise "Expected annotation" if not xml_annotation # Not sure if this could happen?
          base = QName.new(xml_annotation['base'], namespaces)
          inheritance_style = xml_annotation.node_name == 'extension' ? :extension : :restriction
        end
        xml_root = xml_annotation || xml_typedef
        attributes = xml_root.xpath('./xs:attribute', ns_xs).map do |xml_attribute|
          parse_attribute(xml_attribute, namespaces)
        end
        attribute_groups = xml_root.xpath('./xs:attributeGroup', ns_xs).map do |xml_attribute_group|
          parse_attribute_group(xml_attribute_group, namespaces)
        end
        xml_structure = xml_root.xpath('./xs:all|xs:choice|xs:sequence', ns_xs).first
        if xml_structure
          element_structure = parse_element_structure(xml_structure, namespaces)
        end
        ComplexType.new(name, base, content_style, inheritance_style, attributes, attribute_groups, element_structure)
      end

      def parse_element_structure(xml_structure, namespaces)
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        if xml_structure.node_name == 'all'
          elements = xml_structure.xpath('./xs:element', ns_xs).map do |xml_element|
            parse_element(xml_element, namespaces)
          end
          ElementStructureAll.new(elements)
        elsif xml_structure.node_name == 'sequence'
          elements = xml_structure.xpath('./xs:element|xs:group|xs:choice|xs:sequence', ns_xs).map do |xml_structure_structure|
            if xml_structure_structure.node_name == 'element'
              parse_element(xml_structure_structure, namespaces)
            else
              parse_element_structure(xml_structure_structure, namespaces)
            end
          end
          ElementStructureSequence.new(elements)
        elsif xml_structure.node_name == 'choice'
          elements = xml_structure.xpath('./xs:element|xs:group|xs:choice|xs:sequence', ns_xs).map do |xml_structure_structure|
            if xml_structure_structure.node_name == 'element'
              parse_element(xml_structure_structure, namespaces)
            else
              parse_element_structure(xml_structure_structure, namespaces)
            end
          end
          ElementStructureChoice.new(elements)
        elsif xml_structure.node_name == 'group'
          elements = xml_structure.xpath('./xs:all|xs:choice|xs:sequence', ns_xs).map do |xml_structure_structure|
            parse_element_structure(xml_structure_structure, namespaces)
          end
          if xml_structure['ref']
            raise "Definitions inside referring xs:group not valid" if elements.any?
            ElementGroupReference.new(QName(xml_structure['ref'], namespaces))
          else
            ElementGroup.new(xml_structure['name'] ? QName(xml_structure['name'], namespaces) : nil, elements)
          end
        else
          raise "Unsupported structural type '#{xml_structure.node_name}'"
        end
      end

      def parse_attribute(xml_attribute, namespaces)
        if xml_attribute['ref']
          AttributeReference.new(QName(xml_attribute['ref'], namespaces), xml_attribute['default'], xml_attribute['fixed'], xml_attribute['use'])
        else
          # Could have a type definition, which can be used for generating rules .. I'm ignoring this for now.
          # See also `parse_simple_type`
          Attribute.new(
                        xml_attribute['name'] ? QName(xml_attribute['name'], namespaces) : nil,
                        xml_attribute['default'],
                        xml_attribute['fixed'],
                        xml_attribute['use'])
        end
      end

      def parse_attribute_group(xml_attribute_group, namespaces)
        attributes = xml_attribute_group.xpath('./xs:attribute', ns_xs).map do |xml_attribute|
          parse_attribute(xml_attribute, namespaces)
        end
        attribute_groups = xml_attribute_group.xpath('./xs:attributeGroup', ns_xs).map do |xml_attribute_group_group|
          parse_attribute_group(xml_attribute_group_group, namespaces)
        end
        if xml_attribute_group['ref']
          raise "TODO: Definitions inside referring xs:attributeGroup not supported" if attributes.any? || attribute_groups.any?
          AttributeGroupReference.new(QName(xml_attribute_group['ref'], namespaces))
        else
          AttributeGroup.new(xml_attribute_group['name'] ? QName(xml_attribute_group['name'], namespaces) : nil, attributes, attribute_groups)
        end
      end

      def parse_simple_type(xml_typedef, namespaces)
        ns_xs = {'xs' => 'http://www.w3.org/2001/XMLSchema'}
        name = xml_typedef['name']
        qname = xml_typedef['name'] ? QName.new(xml_typedef['name'], namespaces) : nil
        xml_annotation = xml_content.xpath('./xs:restriction|xs:list|xs:union', ns_xs).first
        raise "Expected annotation" if not xml_annotation # Not sure why someone would define a simpleType without any annotations ?!?
        case xml_annotation.node_name
        when 'list'
          # More nasty loop-holes in the type-system .. allows multiple values to be serialised into a string
          # Good luck parsing that ...
          ListType.new(name, qname, QName.new(xml_annotation['itemType'], namespaces))
        when 'union'
          # Multiple inheritance .. only allowed for simple types
          # For some reason, it's allowed to inline a simpleType here, which simply does not make sense .. *sigh*
          raise "TODO: xs:simpleType element not supported here" if xml_annotation.children.any?
          typenames = xml_annotation['memberTypes'].split(' ').map do |typename|
            QName.new(typename, namespaces)
          end
          UnionType.new(name, qname, typenames)
        when 'restriction'
          # Adds syntactical restriction on the primitive type
          # Could be used for generating automatic validations on input
          # I'm lazy however, so I'll just skip that for now and leave the service to deal with violations
          base = QName.new(xml_annotation['base'], namespaces)
          SimpleType.new(name, qname, base)
        end
      end
    end

    # typedefs

    class ElementStructureAll
      attr_reader :elements
      def initialize(elements)
        @elements = elements
      end
    end

    class ElementStructureSequence
      attr_reader :elements
      def initialize(elements)
        @elements = elements
      end
    end

    class ElementStructureChoice
      attr_reader :elements
      def initialize(elements)
        @elements = elements
      end
    end

    class ElementGroup
      attr_reader :name, :elements
      def initialize(name, elements)
        @name = name
        @elements = elements
      end
    end

    class ElementGroupReference
      attr_reader :ref
      def initialize(ref)
        @ref = ref
      end
    end

    class AttributeGroup
      attr_reader :name, :attributes, :attribute_groups
      def initialize(name, attributes, attribute_groups)
        @name = name
        @attributes = attributes
        @attribute_groups = attribute_groups
      end
      def flatten
        @attributes + @attribute_groups.flatten
      end
    end

    class AttributeGroupReference
      attr_reader :ref
      def initialize(ref)
        @ref = ref
      end
    end

    class Attribute
      attr_reader :name, :default, :fixed, :use
      def initialize(name, default, fixed, use)
        @name = name
        @default = default
        @fixed = fixed
        @use = use
      end
      def optional?
        @use.nil? || @use == 'optional'
      end
      def prohibited?
        @use == 'prohibited'
      end
      def required?
        @use == 'required'
      end
    end

    class AttributeReference
      attr_reader :ref, :default, :fixed, :use
      def initialize(ref, default, fixed, use)
        @ref = ref
        @default = default
        @fixed = fixed
        @use = use
      end
      def optional?
        @use.nil? || @use == 'optional'
      end
      def prohibited?
        @use == 'prohibited'
      end
      def required?
        @use == 'required'
      end
    end

    class ComplexType
      attr_reader :name, :base, :content_style, :inheritance_style, :attributes, :attribute_groups, :element_structure
      def initialize(name, base, content_style, inheritance_style, attributes, attribute_groups, element_structure)
        @name = name
        @base = base
        @content_style = content_style
        @inheritance_style = inheritance_style
        @attributes = attributes
        @attribute_groups = attribute_groups
        @element_structure = element_structure
      end
      def simple_content?
        @content_style == :simple
      end
      def complex_content?
        @content_style == :complex
      end
      # This is a regular class-inheritance. It adds new stuff to the parent class.
      def extension?
        @inheritance_style == :extension
      end
      # This is a class-inheritance, which restricts already defined components of the superclass .. Liskov wouldn't be happy
      def restriction?
        @inheritance_style == :restriction
      end
    end

    class SimpleType
      attr_reader :name, :type
      def initialize(name, type)
        @name = name
        @type = type
      end
    end

    class UnionType
      attr_reader :name, :type, :inherited_types
      def initialize(name, type, inherited_types)
        @name = name
        @type = type
        @inherited_types = inherited_types
      end
    end

    class ListType
      attr_reader :name, :type, :item_type
      def initialize(name, type, item_type)
        @name = name
        @type = type
        @item_type = item_type
      end
    end

    class Element
      attr_reader :name, :type, :typedef, :default, :fixed, :substitution_group
      def initialize(name, type, typedef, default, fixed, substitution_group)
        @name = name
        @type = type
        @typedef = typedef
        @default = default
        @fixed = fixed
        @substitution_group = substitution_group
      end
    end

    # service defs

    class Part
      attr_reader :name, :type
      def initialize(name, type)
        @name = name
        @type = type
      end
    end

    class MessageType
      attr_reader :name, :type
      def initialize(name, type)
        @name = name
        @type = type
      end
    end

    class Binding
      attr_reader :name, :type, :soap_version, :style, :transport, :operations
      attr_writer :operations
      def initialize(name, type, soap_version, style, transport)
        @name = name
        @type = type
        @soap_version = soap_version
        @style = style
        @transport = transport
        @operations = {}
      end
      def rpc_style?
        style == 'rpc'
      end
      def document_style?
        style == 'document'
      end
    end

    class Operation
      attr_reader :name, :soap_action, :messages
      def initialize(name, soap_action)
        @name = name
        @soap_action = soap_action
        @messages = {}
      end
    end

    class Section
      attr_reader :name, :use, :encoding_style, :namespace
      def initialize(name, use, encoding_style, namespace)
        @name = name
        @use = use
        @encoding_style = encoding_style
        @namespace = namespace
      end
      def encoded?
        use == "encoded" || encoding_style == "http://schemas.xmlsoap.org/soap/encoding/"
      end
    end

    class Port
      attr_reader :name, :binding, :location
      def initialize(name, binding, location)
        @name = name
        @binding = binding
        @location = location
      end
    end
  end
end
