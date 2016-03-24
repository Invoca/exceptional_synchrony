#!/usr/bin/env rake

desc 'Run entire test suite.'
task :run do
  require './test/test_helper.rb'
  Dir.glob('./test/**/*_test.rb') { |f| require f }

end

task :default => :run
