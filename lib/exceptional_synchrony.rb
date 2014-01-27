require 'hobo_support' # Not sure why bundler isn't requiring this automatically? -Colin
require 'em-synchrony/em-http'

module ExceptionalSynchrony
end

require_relative 'exceptional_synchrony/callback_exceptions'
require_relative 'exceptional_synchrony/event_machine_proxy'
require_relative 'exceptional_synchrony/limited_work_queue'
require_relative 'exceptional_synchrony/parallel_sync'
require_relative 'exceptional_synchrony/version'
