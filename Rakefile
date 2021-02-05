#!/usr/bin/env rake
# frozen_string_literal: true

require "bundler/gem_tasks"
require 'rake/testtask'

task default: :test

Rake::TestTask.new do |t|
  t.warning = false
  t.pattern = "test/**/*_test.rb"
end

