# -*- coding: utf-8 -*-

module Handsoap

  class Compiler

    class ComplexTypeFront
      def initialize(complex_type)
        @complex_type = complex_type
      end
      def name
        @complex_type.name
      end
      def attributes
        @complex_type.attributes + @complex_type.attribute_groups.map { |group| group.flatten }.flatten
      end
      def element_structure
        @complex_type.element_structure
      end
    end

    class CodeWriter
      def initialize
        @buffer = ""
        @indentation = 0
      end
      def begin(text)
        puts(text)
        indent
      end
      def end
        unindent
        puts("end")
      end
      def puts(text)
        @buffer = @buffer + text.gsub(/^(.*)$/, ("  " * @indentation) + "\\1")
        @buffer = @buffer + "\n" if ! @buffer.match(/\n$/)
      end
      def indent
        @indentation = @indentation + 1
      end
      def unindent
        @indentation = @indentation - 1
      end
      def to_s
        @buffer
      end
    end

    def initialize(wsdl, class_name, file_name)
      # Interesting reading:
      #   http://www.ibm.com/developerworks/webservices/library/ws-whichwsdl/
      # TODO 1.1 vs. 1.2
      # http://www.w3.org/TR/soap12-part0/#L4697
      # Faults
      # In the SOAP 1.2 HTTP binding, the Content-type header should be "application/soap+xml" instead of "text/xml" as in SOAP 1.1. The IETF registration for this new media type is [RFC 3902].
      # The syntax for the serialization of an array has been changed in SOAP 1.2 from that in SOAP 1.1. (What does that mean?)
      # SOAP 1.2 has added an optional attribute enc:nodeType to elements encoded using SOAP encoding that identifies its structure (i.e., a simple value, a struct or an array).
      @wsdl = wsdl
      @class_name = class_name
      @file_name = file_name
      @xml_namespaces = {}
      @context_names = {}
      @encode_input = nil
      # TODO: Remove SOAP_NAMESPACE from Service, and generate it instead
      # SOAP 1.1 'http://schemas.xmlsoap.org/soap/envelope'
      # SOAP 1.2 'http://www.w3.org/2001/12/soap-encoding'
      @common_namespaces = {
        "http://schemas.xmlsoap.org/soap/encoding" => 'soapenc',
        "http://www.w3.org/2001/XMLSchema" => 'xs',
        "http://www.w3.org/2001/XMLSchema-instance" => 'xsi'
      }
    end

    def write
      writer = CodeWriter.new
      yield writer
      writer.to_s
    end

    def compile(binding)
      @xml_namespaces = {}
      @context_names = {}
      @encode_input = nil
      operations = binding.operations.values.map do |operation|
        # TODO:
        #         # This is ridiculous!
        #         # Find the port_type for this binding
        #         port_type = @wsdl.port_types[binding.type.name]
        #         # Find the port_operation for the matching binding_operation
        #         port_operation = port_type[operation.name]
        #         compile_operation(operation, port_operation, binding)
        message = @wsdl.messages[operation.name] || raise "Couldn't find message for '#{operation.name}'"
        compile_operation(operation, message, binding)
      end
      # TODO: only generate builders for types that are actually used for input
      builders = @wsdl.types.values.map do |typedef|
        compile_builder(typedef)
      end

      write do |w|
        w.puts "# -*- coding: utf-8 -*-"
        w.puts "require 'handsoap'"
        w.begin "class #{@class_name}Service < Handsoap::Service"
        w.puts "endpoint #{@file_name.upcase}_SERVICE_ENDPOINT"
        w.puts ""
        w.begin "on_create_document do |doc|"
        @xml_namespaces.each do |href, ns|
          w.puts "doc.alias '#{ns}', \"#{href}\""
        end
        w.end
        w.puts ""
        operations.each do |operation|
          w.puts operation
          w.puts ""
        end
        builders.each do |builder|
          w.puts builder
          w.puts ""
        end
        w.end
      end
    end

    def compile_operation(operation, message, binding)
      # TODO: I think it's wrong to use soap_action here .. there is a name attribute on the operation-node itself, that probably is a better fit
      # TODO: map output
      flush_context!
      ruby_operation_name = underscore(operation.soap_action)
      input = operation.messages['input']['body'] if operation.messages['input']
      output = operation.messages['output']['body'] if operation.messages['output']
      if input
        if @encode_input.nil?
          @encode_input = input.encoded?
        else
          raise "Can't mix literal and encoded operation in same binding" if @encode_input != input.encoded?
        end
      end
      write do |w|
        if input
          # if style = document, we don't get any ns for the operation name
          if binding.rpc_style?
            message_qname = Handsoap::Parser::QName.new("tns:#{operation.name}", {'xmlns:tns' => input.namespace})
            invoke_node_name = xml_name(message_qname)
          else
            invoke_node_name = operation.name
          end
          argument_names = []
          message.each do |part|
            # calculate varname
            base_name = underscore(part.name)
            if argument_names.include?(base_name)
              postfix = argument_names.select { |name| /^#{base_name}/.match(name) }.length + 1
              argument_names << base_name + "_" + postfix.to_s
            else
              argument_names << base_name
            end
          end
          w.begin "def #{ruby_operation_name}(" + argument_names.join(", ") + ")"
          w.begin((output ? 'response = ' : '') + "invoke('#{invoke_node_name}') do |message|")
          if @encode_input
            encoding_style_name = Handsoap::Parser::QName.new('soap:encodingStyle', {'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/encoding/'})
            w.puts "message.set_attr '#{xml_name(encoding_style_name)}', '#{input.encoding_style}'"
          end
          message.each do |part|
            # A part will always be a reference type.
            varname = argument_names.shift
            w.puts compile_reference_type(part.name, part.type, 'message', varname)
          end
          w.end
        else
          # no input
          if binding.rpc_style?
            message_qname = Handsoap::Parser::QName.new("tns:#{operation.name}", {'xmlns:tns' => output.namespace})
            invoke_node_name = xml_name(message_qname)
          else
            invoke_node_name = operation.name
          end
          w.begin "def #{ruby_operation_name}"
          w.puts((output ? 'response = ' : '') + "invoke('#{invoke_node_name}')")
        end
        if output
          w.puts "# TODO: map response -> ruby"
        end
        w.end
      end
    end

    def compile_builder(complex_type)
      flush_context!
      qname_xsi_type = Handsoap::Parser::QName.new("xsi:type", {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'})
      write do |w|
        w.puts "# #{complex_type.name.name} ruby -> xml"
        w.begin "def build_#{rb_name(complex_type)}!(context, #{rb_name(complex_type)})"
        if @encode_input
          # add type (only when style=encoded)
          w.puts "context.set_attr '#{xml_name(qname_xsi_type)}', '#{xml_name(complex_type)}'"
        end
        w.puts compile_attributes(complex_type, 'context')
        w.puts compile_structure(complex_type.element_structure, 'context', complex_type)
        w.end
      end
    end

    def compile_attributes(typedef, context_name, has_attributes = nil)
      # TODO: defauls
      # TODO: booleans
      # TODO: are unions and lists allowed here?
      str = ""
      has_attributes = typedef if has_attributes.nil?
      if has_attributes.kind_of?(Handsoap::Parser::ComplexType) && has_attributes.base
        # inherited
        str << compile_attributes(typedef, context_name, @wsdl.complex_types[has_attributes.base])
      end
      has_attributes.attribute_groups.each do |attribute|
        # mixin
        if attribute.kind_of? Handsoap::Parser::AttributeGroup
          str << compile_attributes(typedef, context_name, attribute)
        elsif attribute.kind_of? Handsoap::Parser::AttributeGroupReference
          str << compile_attributes(typedef, context_name, @wsdl.attribute_groups[attribute.ref.full_name])
        else
          raise "Unexpected, that is"
        end
      end
      has_attributes.attributes.each do |attribute|
        # own
        if attribute.kind_of? Handsoap::Parser::AttributeReference
          attributedef = @wsdl.attributes[attribute.ref.full_name]
        else
          attributedef = attribute
        end
        str << "#{context_name}.set_attr " + '"' + xml_name(typedef) + '", ' + rb_name(typedef) + "[:" + rb_name(attributedef) + "]" + "\n"
      end
      return str
    end

    def compile_reference_type(element_name, ref, context_name, varname)
      write do |w|
        inner_context_name = ctx_name(Handsoap::Parser::QName.new("ns:#{element_name}", {'xmlns:ns' => ref.namespace}))
        typedef = @wsdl.types.values.find { |t| t.name.full_name == ref.full_name }
        if typedef.nil? || typedef.kind_of?(Handsoap::Parser::SimpleType) || typedef.kind_of?(Handsoap::Parser::UnionType) || typedef.kind_of?(Handsoap::Parser::ListType)
          # Part is a simple type
          w.begin "#{context_name}.add '#{element_name}' do |#{inner_context_name}|"
          if @encode_input
            qname_xsi_type = Handsoap::Parser::QName.new("xsi:type", {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'})
            w.puts "#{inner_context_name}.set_attr '#{xml_name(qname_xsi_type)}', '#{xml_name(ref)}'"
          end
          if typedef.kind_of?(Handsoap::Parser::ListType)
            w.puts "#{inner_context_name}.set_value #{varname}.join(' ')"
          else
            w.puts "#{inner_context_name}.set_value #{varname}"
          end
          w.end
        else
          # Part is a complex type
          w.begin "#{context_name}.add '#{element_name}' do |#{inner_context_name}|"
          w.puts "build_#{rb_name(typedef)}! #{inner_context_name}, #{varname}"
          w.end
        end
      end
    end

    def compile_structure(structure, context_name, complex_type)
      # TODO: conflate inherited structures
      write do |w|
        if structure.kind_of?(Handsoap::Parser::ElementStructureAll) || structure.kind_of?(Handsoap::Parser::ElementStructureSequence)
          # TODO: cardinality
          structure.elements.each do |element|
            typedef = element.typedef
            if typedef
              raise "TODO: Inline typedef"
            else
              varname = rb_name(complex_type) + "[:" + rb_name(element) + "]"
              w.puts compile_reference_type(element.name.name, element.type, context_name, varname)
            end
          end
        elsif structure.kind_of? Handsoap::Parser::ElementGroup
          # NOTE: dunno if this works as expected ..
          structure.elements.each do |element|
            w.puts compile_structure(element, context_name, complex_type)
          end
        elsif structure.kind_of? Handsoap::Parser::ElementGroupReference
          raise "TODO: ElementGroupReference"
        elsif structure.kind_of? Handsoap::Parser::ElementStructureChoice
          raise "TODO: ElementStructureChoice"
        else
          raise "Unsupported structural type #{structure.class}"
        end
      end
    end

    def rb_name(maybe_name)
      maybe_name.kind_of?(Handsoap::Parser::QName) ? underscore(maybe_name.name) : rb_name(maybe_name.name)
    end

    def flush_context!
      @context_names = {}
    end

    def ctx_name(typedef)
      hash = rb_name(typedef)
      if not @context_names[hash]
        ii = 1
        candidate = hash[0, ii]
        while @context_names.values.include?(candidate) do
          ii = ii + 1
          candidate = hash[0, ii]
        end
        @context_names[hash] = candidate
      end
      @context_names[hash]
      # "ctx_" + rb_name(typedef)
    end

    def xml_name(maybe_name)
      if maybe_name.kind_of?(Handsoap::Parser::QName)
        if not @xml_namespaces[maybe_name.namespace]
          reverse = @wsdl.namespaces.invert
          if @common_namespaces[maybe_name.namespace]
            @xml_namespaces[maybe_name.namespace] = @common_namespaces[maybe_name.namespace]
          elsif reverse[maybe_name.namespace] && reverse[maybe_name.namespace] != 'xmlns' && !@xml_namespaces.include?(reverse[maybe_name.namespace].gsub(/^xmlns:/, ''))
            @xml_namespaces[maybe_name.namespace] = reverse[maybe_name.namespace].gsub(/^xmlns:/, '')
          else
            @xml_namespaces[maybe_name.namespace] = "autons" + (@xml_namespaces.length + 1).to_s
          end
        end
        @xml_namespaces[maybe_name.namespace] + ":" + maybe_name.name
      else
        xml_name(maybe_name.name)
      end
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
end

