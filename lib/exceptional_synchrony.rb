require 'hobo_support'
require 'em-synchrony'
require 'em-synchrony/em-http'
begin
  require 'exception_handling'
rescue Exception => ex
  raise "rescued exception #{ex.inspect} in RUBY_VERSION #{RUBY_VERSION}"
end


module ExceptionalSynchrony
end

require_relative 'exceptional_synchrony/callback_exceptions'
require_relative 'exceptional_synchrony/event_machine_proxy'
require_relative 'exceptional_synchrony/limited_work_queue'
require_relative 'exceptional_synchrony/parallel_sync'
require_relative 'exceptional_synchrony/version'
