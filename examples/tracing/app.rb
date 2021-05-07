# frozen_string_literal: true

require "exceptional_synchrony"
require "exception_handling"
require "logger"

module Tracing
  class App
    class << self
      attr_accessor :tracer

      delegate :trace, to: :tracer
    end

    def initialize(config, logger, factory, tracer)
      @config  = config
      @factory = factory
      @logger  = ExceptionHandling.logger = logger
      self.class.tracer = tracer
    end

    def run!
      ExceptionalSynchrony::EMP.run do
        work_loop
      end
    end

    private

    def work_loop
      end_at = Time.now + @config.max_runtime_seconds
      ExceptionHandling.log_info("Starting with config #{@config.to_h.inspect}")
      while Time.now < end_at
        if (work = @factory.build(depth: 0))
          work.schedule(trace: true)
        end
        ExceptionalSynchrony::EMP.sleep(1)
      end
      ExceptionHandling.log_info("shutting down...")
      ExceptionalSynchrony::EMP.stop
    end
  end
end