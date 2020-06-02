# This class is for Dependency Injection of EventMachine.  All EventMachine interactions should go through here.

require 'eventmachine'
require 'em-http'
require 'em-synchrony/em-http'

module ExceptionalSynchrony
  # It is important for this exception to be inherited from Exception so that
  # when thrown it does not get caught by the EventMachine.error_handler.
  class FatalRunError < Exception; end

  class EventMachineProxy

    attr_reader :connection

    WRAP_WITH_ENSURE_COMPLETELY_SAFE = (ENV['RACK_ENV'] != 'test')

    def initialize(proxy_class, connection_class)
      @proxy_class = proxy_class
      @synchrony = defined?(@proxy_class::Synchrony) ?  @proxy_class::Synchrony : @proxy_class
      @connection = connection_class

      proxy_class.error_handler do |error|
        ExceptionHandling.log_error(error, "ExceptionalSynchrony uncaught exception: ")
      end
    end

    def add_timer(seconds, &block)
      @synchrony.add_timer(seconds) do
        ensure_completely_safe("add_timer") do
          block.call
        end
      end
    end

    def add_periodic_timer(*args, &block)
      @synchrony.add_periodic_timer(*args) do
        ensure_completely_safe("add_periodic_timer") do
          block.call
        end
      end
    end

    def sleep(seconds)
      @synchrony.sleep(seconds)
    end

    def yield_to_reactor
      if reactor_running?
        @synchrony.sleep(0)
      end
    end

    def next_tick(&block)
      @synchrony.next_tick do
        ensure_completely_safe("next_tick") do
          block.call
        end
      end
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
