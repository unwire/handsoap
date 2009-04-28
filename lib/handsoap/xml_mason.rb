# -*- coding: utf-8 -*-

module Handsoap

  module XmlMason

    HTML_ESCAPE = { '&' => '&amp;', '"' => '&quot;', '>' => '&gt;', '<' => '&lt;' }

    def self.html_escape(s)
      s.to_s.gsub(/[&"><]/) { |special| HTML_ESCAPE[special] }
    end

    class Node
      def initialize
        @namespaces = {}
      end
      def add(node_name, value = nil, options = {})
        prefix, name = parse_ns(node_name)
        node = append_child Element.new(self, prefix, name, value, options)
        if block_given?
          yield node
        end
      end
      def alias(prefix, namespaces)
        @namespaces[prefix] = namespaces
      end
      def parse_ns(name)
        matches = name.match /^([^:]+):(.*)$/
        if matches
          [matches[1] == '*' ? @prefix : matches[1], matches[2]]
        else
          [nil, name]
        end
      end
      private :parse_ns
    end

    class Document < Node
      def initialize
        super
        @document_element = nil
        if block_given?
          yield self
        end
      end
      def append_child(node)
        if not @document_element.nil?
          raise "There can only be one element at the top level."
        end
        @document_element = node
      end
      def find(name)
        @document_element.find(name)
      end
      def find_all(name)
        @document_element.find_all(name)
      end
      def get_namespace(prefix)
        @namespaces[prefix] || raise("No alias registered for prefix '#{prefix}'")
      end
      def defines_namespace?(prefix)
        false
      end
      def to_s
        if @document_element.nil?
          raise "No document element added."
        end
        "<?xml version='1.0' ?>" + "\n" + @document_element.to_s
      end
    end

    class TextNode
      def initialize(text)
        @text = text
      end
      def to_s(indentation = '')
        XmlMason.html_escape(@text).gsub(/\n/, "\n" + indentation)
      end
    end

    class Element < Node
      def initialize(parent, prefix, node_name, value = nil, options = {})
        super()
#         if prefix.to_s == ""
#           raise "missing prefix"
#         end
        @parent = parent
        @prefix = prefix
        @node_name = node_name
        @children = []
        @attributes = {}
        @indent_children = options[:indent] != false # default to true, can override to false
        if not value.nil?
          set_value value.to_s
        end
        if block_given?
          yield self
        end
      end
      def full_name
        @prefix.nil? ? @node_name : (@prefix + ":" + @node_name)
      end
      def append_child(node)
        if value_node?
          raise "Element already has a text value. Can't add nodes"
        end
        @children << node
        return node
      end
      def set_value(value)
        if @children.length > 0
          raise "Element already has children. Can't set value"
        end
        @children = [TextNode.new(value)]
      end
      def set_attr(name, value)
        full_name = parse_ns(name).join(":")
        @attributes[name] = value
      end
      def find(name)
        if @node_name == name || full_name == name
          return self
        end
        @children.each do |node|
          if node.respond_to? :find
            tmp = node.find(name)
            if tmp
              return tmp
            end
          end
        end
        return nil
      end
      def find_all(name)
        result = []
        if @node_name == name || full_name == name
          result << self
        end
        @children.each do |node|
          if node.respond_to? :find
            result = result.concat(node.find_all(name))
          end
        end
        return result
      end
      def value_node?
        @children.length == 1 && @children[0].kind_of?(TextNode)
      end
      def get_namespace(prefix)
        @namespaces[prefix] || @parent.get_namespace(prefix)
      end
      def defines_namespace?(prefix)
        @attributes.keys.include?("xmlns:#{prefix}") || @parent.defines_namespace?(prefix)
      end
      def to_s(indentation = '')
        # todo resolve attribute prefixes aswell
        if @prefix && (not defines_namespace?(@prefix))
          set_attr "xmlns:#{@prefix}", get_namespace(@prefix)
        end
        name = XmlMason.html_escape(full_name)
        attr = (@attributes.any? ? (" " + @attributes.map { |key, value| XmlMason.html_escape(key) + '="' + XmlMason.html_escape(value) + '"' }.join(" ")) : "")
        if @children.any?
          child_indent = @indent_children ? (indentation + "  ") : ""
          if value_node?
            children = @children[0].to_s(child_indent)
          else
            children = @children.map { |node| "\n" + node.to_s(child_indent) }.join("") + "\n" + indentation
          end
          indentation + "<" + name + attr + ">" + children + "</" + name + ">"
        else
          indentation + "<" + name + attr + " />"
        end
      end
    end
  end

end
