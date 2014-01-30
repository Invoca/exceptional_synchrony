require 'hobo_support'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'exception_handling'


module ExceptionalSynchrony
end

require_relative 'exceptional_synchrony/callback_exceptions'
require_relative 'exceptional_synchrony/event_machine_proxy'
require_relative 'exceptional_synchrony/limited_work_queue'
require_relative 'exceptional_synchrony/parallel_sync'
require_relative 'exceptional_synchrony/version'
