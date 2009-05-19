require 'rubygems'
require 'rails_generator'
require "#{File.dirname(__FILE__)}/../generators/handsoap/handsoap_generator.rb"
require 'rails_generator/scripts/generate'

# This is a messy way of mocking out the generator, since I couldn't find a smarter way

class HandsoapGenerator
  class DummySpec
    def name
      "handsoap_test"
    end
    def path
      "/tmp/path"
    end
  end
  def spec
    DummySpec.new
  end
end

module Rails::Generator::Scripts
  class Generate < Base
    def run(args = [], runtime_options = {})
      begin
        parse!(args.dup, runtime_options)
      rescue OptionParser::InvalidOption => e
        # Don't cry, script. Generators want what you think is invalid.
      end
      options[:generator] = 'handsoap'
      HandsoapGenerator.new(args, full_options(options)).command(options[:command]).invoke!
    rescue => e
      puts e
      puts "  #{e.backtrace.join("\n  ")}\n" if options[:backtrace]
      raise SystemExit
    end
  end
end


