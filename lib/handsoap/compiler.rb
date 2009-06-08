# -*- coding: utf-8 -*-
module Handsoap
  module Compiler
    class CodeWriter

      def initialize
        @buffer = ""
        @indentation = 0
      end

      def begin(text)
        puts(text)
        indent
      end

      def end(str = "end")
        unindent
        puts(str)
      end

      def puts(text = "")
        @buffer << text.gsub(/^(.*)$/, ("  " * @indentation) + "\\1")
        @buffer << "\n" # unless @buffer.match(/\n$/)
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

    def self.write
      writer = CodeWriter.new
      yield writer
      writer.to_s
    end

    def self.underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    def self.camelize(lower_case_and_underscored_word)
      lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) {
        "::" + $1.upcase
      }.gsub(/(^|_)(.)/) {
        $2.upcase
      }
    end

    def self.method_name(operation)
      if operation.name.match /^(get|find|select|fetch)/i
        "#{underscore(operation.name)}"
      else
        "#{underscore(operation.name)}!"
      end
    end

    def self.service_basename(wsdl)
      underscore(wsdl.service).gsub(/_service$/, "")
    end

    def self.service_name(wsdl)
      camelize(service_basename(wsdl)) + "Service"
    end

    def self.endpoint_name(wsdl)
      "#{service_basename(wsdl).upcase}_SERVICE_ENDPOINT"
    end

    def self.detect_protocol(wsdl)
      if endpoints.select { |endpoint| endpoint.protocol == :soap12 }.any?
        :soap12
      elsif endpoints.select { |endpoint| endpoint.protocol == :soap11 }.any?
        :soap11
      else
        raise "Can't find any soap 1.1 or soap 1.2 endpoints"
      end
    end

    def self.compile_endpoints(wsdl, protocol)
      version = protocol == :soap12 ? 2 : 1
      wsdl.endpoints.select { |endpoint| endpoint.protocol == protocol }.map do |endpoint|
        write do |w|
          w.puts "# wsdl: #{wsdl.url}"
          w.begin "#{endpoint_name(wsdl)} = {"
          w.puts ":uri => '#{endpoint.url}',"
          w.puts ":version => #{version}"
          w.end "}"
        end
      end
    end

    def self.compile_service(wsdl, protocol, *options)
      binding = wsdl.bindings.find { |b| b.protocol == protocol }
      raise "Can't find binding for requested protocol (#{protocol})" unless binding
      write do |w|
        w.puts "# -*- coding: utf-8 -*-"
        w.puts "require 'handsoap'"
        w.puts
        w.begin "class #{service_name(wsdl)} < Handsoap::Service"
        w.puts "endpoint #{endpoint_name(wsdl)}"
        w.begin "on_create_document do |doc|"
        w.puts "doc.alias 'tns', '#{wsdl.target_ns}'"
        w.end
        w.puts
        w.puts "# public methods"
        wsdl.interface.operations.each do |operation|
          action = binding.actions.find { |a| a.name == operation.name }
          raise "Can't find action for operation #{operation.name}" unless action
          w.puts
          w.begin "def #{method_name(operation)}"
          # TODO allow :soap_action => :none
          if operation.name != action.soap_action && options.include?(:soap_actions)
            w.puts "soap_action = '#{action.soap_action}'"
            maybe_soap_action = ", soap_action"
          else
            maybe_soap_action = ""
          end
          w.begin((operation.output ? 'response = ' : '') + "invoke('tns:#{operation.name}'#{maybe_soap_action}) do |message|")
          w.puts 'raise "TODO"'
          w.end
          w.end
        end
        w.puts
        w.puts "private"
        w.puts "# helpers"
        w.puts "# TODO"
        w.end
      end
    end

    def self.compile_test(wsdl, protocol)
      binding = wsdl.bindings.find { |b| b.protocol == protocol }
      raise "Can't find binding for requested protocol (#{protocol})" unless binding
      write do |w|
        w.puts "# -*- coding: utf-8 -*-"
        w.puts "require 'test_helper'"
        w.puts
        w.puts "# #{service_name(wsdl)}.logger = $stdout"
        w.puts
        w.begin "class #{service_name(wsdl)}Test < Test::Unit::TestCase"
        wsdl.interface.operations.each do |operation|
          w.puts
          w.begin "def test_#{underscore(operation.name)}"
          w.puts "result = #{service_name(wsdl)}.#{method_name(operation)}"
          w.end
        end
        w.end
      end
    end
  end
end
