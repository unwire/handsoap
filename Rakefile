# -*- coding: utf-8 -*-
begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "handsoap"
    gemspec.summary = "Handsoap is a library for creating SOAP clients in Ruby"
    gemspec.email = "troelskn@gmail.com"
    gemspec.homepage = "http://github.com/troelskn/handsoap"
    gemspec.description = gemspec.summary
    gemspec.authors = ["Troels Knak-Nielsen"]
    gemspec.requirements << "You need to install either \"curb\" or \"httpclient\", using one of:\n    gem install curb\n    gem install httpclient"
    gemspec.requirements << "It is recommended that you install either \"nokogiri\" or \"libxml-ruby\""
    gemspec.files = FileList['lib/**/*.rb', 'generators/handsoap/templates', 'generators/**/*', '[A-Z]*.*'].to_a
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.test_files = FileList.new('tests/**/*_test.rb') do |list|
    list.exclude 'tests/benchmark_integration_test.rb'
    list.exclude 'tests/service_integration_test.rb'
  end
  test.libs << 'tests'
  test.verbose = true
end
