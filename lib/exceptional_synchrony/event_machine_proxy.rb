# This class is for Dependency Injection of EventMachine.  All EventMachine interactions should go through here.

require 'eventmachine'
require 'em-http'
require 'em-synchrony/em-http'

require_relative "./em_tracing"

module ExceptionalSynchrony
  # It is important for this exception to be inherited from Exception so that
  # when thrown it does not get caught by the EventMachine.error_handler.
  class FatalRunError < Exception; end

  class EventMachineProxy
    include EMTracing

    attr_reader :connection

    attr_accessor :trace_filtered_caller_labels

    WRAP_WITH_ENSURE_COMPLETELY_SAFE = (ENV['RACK_ENV'] != 'test')
    ALLOWED_HOOKS = [:on_schedule, :on_start, :on_exception, :on_end].freeze

    def initialize(proxy_class, connection_class)
      @proxy_class = proxy_class
      @synchrony = defined?(@proxy_class::Synchrony) ?  @proxy_class::Synchrony : @proxy_class
      @connection = connection_class
      disable_hooks!

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

    def add_timer(seconds, hooks: {}, operation_name: nil, trace_id: nil, no_trace: false, &block)
      schedule(:add_timer, schedule_method_args: [seconds], hooks: hooks, operation_name: operation_name,
               trace_id: trace_id, no_trace: no_trace, &block)
    end

    def add_periodic_timer(*args, hooks: {}, operation_name: nil, trace_id: nil, no_trace: false, &block)
      schedule(:add_periodic_timer, schedule_method_args: args, hooks: hooks, operation_name: operation_name,
               trace_id: trace_id, no_trace: no_trace, &block)
    end

    def sleep(seconds)
      @synchrony.sleep(seconds)
    end

    def yield_to_reactor
      if reactor_running?
        @synchrony.sleep(0)
      end
    end

    def next_tick(hooks: {}, operation_name: nil, trace_id: nil, no_trace: false, &block)
      schedule(:next_tick, hooks: hooks, operation_name: operation_name,
               trace_id: trace_id, no_trace: no_trace) { block.call }
    end

    def stop
      @proxy_class.stop
      @proxy_class.next_tick { } #Fake out EventMachine's epoll mechanism so we don't block until timers fire
    end

    def connect(server, port = nil, handler = nil, *args, &block)
      @proxy_class.connect(server, port, handler, *args, &block)
    end

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

    def defer(context, &block)
      deferrable = EventMachine::DefaultDeferrable.new

      callback = -> (result) { deferrable.succeed(result) }

      EventMachine.defer(nil, callback) { CallbackExceptions.return_exception(&block) }

      EventMachine::Synchrony.sync(deferrable)

      CallbackExceptions.map_deferred_result(deferrable)
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

    FILTER_CALLER_LABELS = ["schedule", "next_tick", "add_timer", "add_periodic_timer"].freeze

    def schedule(schedule_method, schedule_method_args: [], operation_name: nil,
                 trace_id: nil, no_trace: false, hooks: {}, &block)
      if !@hooks_enabled && hooks.any?
        raise ArgumentError, "cannot schedule with hooks when hooks are disabled"
      else
        operation_name = operation_name || caller_locations.map(&:label).find do |label|
          trace_filtered_caller_labels.exclude?(label)
        end
        if @hooks_enabled && !no_trace
          span = OpenTracing.start_span(
            operation_name,
            trace_id: trace_id,
            tags: { "schedule_method" => schedule_method, "schedule_method_args" => schedule_method_args }
          )
        end
        hook_context = { schedule_method: schedule_method, schedule_method_args: schedule_method_args }
        add_trace_hooks!(hooks, span) if span
        Array(hooks.delete(:on_schedule)).each { |hook| hook.call(hook_context) }
        @synchrony.send(schedule_method, *schedule_method_args) do
          if span
            start_span(span) do
              run_with_hooks(hook_context, **hooks, &block)
            end
          else
            run_with_hooks(hook_context, **hooks, &block)
          end
        end
      end
    end

    def run_with_hooks(context, on_start: nil, on_end: nil, on_exception: nil, &block)
      Array(on_start).each { |hook| hook.call(context) }
      result = ensure_completely_safe(context[:schedule_method].to_s) do
        begin
          block.call
        rescue => ex
          Array(on_exception).each { |hook| hook.call(context, ex) }
          raise ex
        end
      end
      Array(on_end).each { |hook| hook.call(context) }
      result
    end

    def run_with_error_logging(&block)
      ensure_completely_safe("run_with_error_logging") do
        if @proxy_class.respond_to?(:synchrony)
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
          @proxy_class.synchrony(&run_block)
        else
          @proxy_class.run(&run_block)
        end
      end
    end
  end

  EMP = EventMachineProxy.new(EventMachine, EventMachine::HttpRequest)
end
