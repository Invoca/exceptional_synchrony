# This class is for Dependency Injection of EventMachine.  All EventMachine interactions should go through here.

require_relative "./tracing"

module ExceptionalSynchrony
  module EMTracing
    def add_trace_hooks!(hooks, span)
      hooks[:on_schedule] = Array(hooks[:on_schedule]) <<  ->(context) {
        context.each { |key, value| span.set_tag(key, value) }
        span.log_kv(event: "scheduled")
      }

      hooks[:on_start] = Array(hooks[:on_start]) << ->(_context) {
        span.log_kv(event: "started")
      }

      hooks[:on_exception] = Array(hooks[:on_exception]) << ->(_context, ex) {
        span.log_kv(event: "exception", ex_class: ex.class.to_s, ex_message: ex.message)
      }

      hooks[:on_end] = Array(hooks[:on_end]) << ->(_context) {
        span.log_kv(event: "ended")
      }
    end

    def start_span(span, &blk)
      OpenTracing.scope_manager.activate(span)
      blk.call
    ensure
      OpenTracing.scope_manager.activate(span) do |scope|
        scope.close
      end
    end
  end
end
