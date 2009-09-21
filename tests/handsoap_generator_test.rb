# -*- coding: utf-8 -*-
require 'rubygems'
require 'test/unit'
require 'rails_generator'
require 'rails_generator/scripts/generate'
require "#{File.dirname(__FILE__)}/../generators/handsoap/handsoap_generator.rb"

module Rails
  module Generator
    module Lookup
      module ClassMethods
        def sources
          [PathSource.new(:user, "#{File.dirname(__FILE__)}/../generators")]
        end
      end
    end
  end
end

class HandsoapGeneratorTest < Test::Unit::TestCase

  def setup
    FileUtils.mkdir_p(fake_rails_root) if File.directory?(fake_rails_root)
    @original_files = file_list
  end

  def invoke_generator!
    Rails::Generator::Scripts::Generate.new.run(["handsoap", "https://mooshup.com/services/system/version?wsdl", "--backtrace", "--quiet"], :destination => fake_rails_root)
  end

  def test_can_invoke_generator
    invoke_generator!
  end

  def test_generator_creates_files
    invoke_generator!
    assert file_list.find {|name| name.match("app/models/version_service.rb") }
    assert file_list.find {|name| name.match("test/integration/version_service_test.rb") }
    assert File.read(fake_rails_root + "/app/models/version_service.rb").any?
    assert File.read(fake_rails_root + "/test/integration/version_service_test.rb").any?
  end

  def test_running_generator_twice_silently_skips_files
    invoke_generator!
    invoke_generator!
  end

  def test_can_parse_multiple_interfaces
    wsdl_file = File.join(File.dirname(__FILE__), 'Weather.wsdl')
    Rails::Generator::Scripts::Generate.new.run(["handsoap", wsdl_file, "--backtrace", "--quiet"], :destination => fake_rails_root)
  end

  private

  def fake_rails_root
    File.join(File.dirname(__FILE__), 'rails_root')
  end

  def file_list
    Dir.glob(File.join(fake_rails_root, "**/*"))
  end
end


