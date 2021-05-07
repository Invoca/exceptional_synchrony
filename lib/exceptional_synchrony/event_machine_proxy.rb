# This class is for Dependency Injection of EventMachine.  All EventMachine interactions should go through here.

require 'eventmachine'
require 'em-http'
require 'em-synchrony/em-http'
require_relative 'faraday_monkey_patch'

module ExceptionalSynchrony
  # It is important for this exception to be inherited from Exception so that
  # when thrown it does not get caught by the EventMachine.error_handler.
  class FatalRunError < Exception; end

  class EventMachineProxy
    #include Tracing

    attr_reader :connection

    attr_accessor :trace_filtered_caller_labels

    WRAP_WITH_ENSURE_COMPLETELY_SAFE = (ENV['RACK_ENV'] != 'test')
    ALLOWED_HOOKS = [:on_schedule, :on_start, :on_exception, :on_end].freeze

    def initialize(proxy_class, connection_class, service_name: nil)
      @proxy_class = proxy_class
      @synchrony = defined?(@proxy_class::Synchrony) ?  @proxy_class::Synchrony : @proxy_class
      @connection = connection_class
      #disable_hooks!
      enable_hooks!


      @trace_filtered_caller_labels = ["schedule", "next_tick", "add_timer", "add_periodic_timer"]

      proxy_class.error_handler do |error|
        ExceptionHandling.log_error(error, "ExceptionalSynchrony uncaught exception: ")
      end
    end


    def enable_hooks!
      @hooks_enabled = true
    end

    def disable_hooks!
      @hooks_enabled = false
    end

    def add_timer(seconds, hooks: {}, span: nil, &block)
      schedule(:add_timer, schedule_method_args: [seconds], hooks: hooks, span: span)
    end

    def add_periodic_timer(*args, hooks: {}, span: nil, &block)
      schedule(:add_periodic_timer, schedule_method_args: args, hooks: hooks, span: span, &block)
    end

    def sleep(seconds)
      @synchrony.sleep(seconds)
    end

    def yield_to_reactor
      if reactor_running?
        @synchrony.sleep(0)
      end
    end

    def next_tick(hooks: {}, span: nil, &block)
      schedule(:next_tick, hooks: hooks, span: span, &block)
    end

    def stop
      @proxy_class.stop
      @proxy_class.next_tick { } #Fake out EventMachine's epoll mechanism so we don't block until timers fire
      Thread.current.thread_variable_set(:em_synchrony_reactor_thread, false)
    end

    def defers_finished?
      @proxy_class.defers_finished?
    end

    def connect(server, port = nil, handler = nil, *args, &block)
      @proxy_class.connect(server, port, handler, *args, &block)
    end

    # This method starts the EventMachine reactor.
    # The on_error option has these possible values:
    #   :log   - log any rescued StandardError exceptions and continue
    #   :raise - raise FatalRunError for any rescued StandardError exceptions
    def run(on_error: :log, &block)
      case on_error
      when :log   then run_with_error_logging(&block)
      when :raise then run_with_error_raising(&block)
      else raise ArgumentError, "Invalid on_error: #{on_error.inspect}, must be :log or :raise"
      end
    end

    # This method will execute the block on the background thread pool
    # By default, it will block the caller until the background thread has finished, so that the result can be returned
    #  :wait_for_result - setting this to false will prevent the caller from being blocked by this deferred work
    def defer(context, wait_for_result: true, &block)
      if wait_for_result
        deferrable = EventMachine::DefaultDeferrable.new
        callback = -> (result) { deferrable.succeed(result) }

        EventMachine.defer(nil, callback) { CallbackExceptions.return_exception(&block) }
        EventMachine::Synchrony.sync(deferrable)
        CallbackExceptions.map_deferred_result(deferrable)
      else
        EventMachine.defer { ExceptionHandling.ensure_completely_safe("defer", &block) }
        nil
      end
    end

    def reactor_running?
      @proxy_class.reactor_running?
    end

    def run_and_stop
      ret = nil
      run do
        ret = yield
        stop
      end
      ret
    end

    def ensure_completely_safe(message)
      if WRAP_WITH_ENSURE_COMPLETELY_SAFE
        ExceptionHandling.ensure_completely_safe(message) do
          yield
        end
      else
        yield
      end
    end

    def rescue_exceptions_and_ensure_exit(context)
      yield
    rescue StandardError => ex
      # Raise a non-StandardError so that not caught by EM.error_handler.
      # Expecting rescued exception to be stored in this new exception's cause.
      raise FatalRunError, "Fatal EventMachine #{context} error\n#{ex.class.name}: #{ex.message}"
    end

    private

    def run_hooks!(key, hooks, context)
      if @hooks_enabled
        Array(hooks.delete(key)).each { |hook| hook.call(context) }
      end
    end

    def schedule(schedule_method, schedule_method_args: [], hooks: {}, span: nil, &block)
      !@hooks_enabled && (hooks.any? || span) and raise RuntimeError, "hooks are disabled"
      context = { schedule_method: schedule_method, schedule_method_args: schedule_method_args }
      set_trace_hooks!(hooks, span) if span
      run_hooks!(:on_schedule, hooks, context)
      @synchrony.send(schedule_method, *schedule_method_args) do
        run_with_hooks(hooks, context, span, &block)
      end
    end

    def run_with_hooks(hooks, context, span, &block)
      run_hooks!(:on_start, hooks, context)
      ensure_completely_safe(context[:schedule_method].to_s) do
        begin
          block.call
        rescue => ex
          run_hooks!(:on_exception, hooks, context.merge(exception: ex))
          raise ex
        else
          run_hooks!(:on_end, hooks, context)
        ensure
          span.finish if span
        end
      end
    end

    def run_with_error_logging(&block)
      ensure_completely_safe("run_with_error_logging") do
        if @proxy_class.respond_to?(:synchrony)
          Thread.current.thread_variable_set(:em_synchrony_reactor_thread, true)
          @proxy_class.synchrony(&block)
        else
          @proxy_class.run(&block)
        end
      end
    end

    def run_with_error_raising(&block)
      run_block = -> { rescue_exceptions_and_ensure_exit("run_with_error_raising", &block) }

      rescue_exceptions_and_ensure_exit("run_with_error_raising") do
        if @proxy_class.respond_to?(:synchrony)
          Thread.current.thread_variable_set(:em_synchrony_reactor_thread, true)
          @proxy_class.synchrony(&run_block)
        else
          @proxy_class.run(&run_block)
        end
      end
    end

    def context_attributes(context)
      (context || {}).reduce({}) do |ctx, (key, value)|
        ctx[key.to_s] = value.inspect
        ctx
      end
    end

    def set_trace_hooks!(hooks, span)
      hooks[:on_schedule] = Array(hooks[:on_schedule]) <<  ->(context) {
        span.add_event("scheduled", attributes: context_attributes(context))
      }
      hooks[:on_start] = Array(hooks[:on_start]) << ->(context) {
        span.add_event("started", attributes: context_attributes(context))
      }
      hooks[:on_exception] = Array(hooks[:on_exception]) << ->(context) {
        ex = context.delete(:exception) or raise RuntimeError, "context #{context.inspect} does not contain key 'exception'"
        exception_context = { "ex_class" => ex.class.to_s, "ex_message" => ex.message }
        span.add_event("exception", attributes: context_attributes(exception_context.merge(context || {})))
      }
      hooks[:on_end] = Array(hooks[:on_end]) << ->(context) {
        span.add_event("ended", attributes: context_attributes(context))
        span.finish
      }
    end
  end

  EMP = EventMachineProxy.new(EventMachine, EventMachine::HttpRequest)
end
