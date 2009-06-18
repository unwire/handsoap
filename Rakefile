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
    gemspec.add_dependency "nokogiri", ">= 1.2.3"
		# We can't depend on these in the gem, since they are pluggable at runtime. You need one or the other though.
#    gemspec.add_dependency "curb", ">= 0.3.2"
#    gemspec.add_dependency "httpclient", ">= 2.1.2"
    gemspec.files = FileList['lib/**/*.rb', 'generators/handsoap/templates', 'generators/**/*', '[A-Z]*.*'].to_a

  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
