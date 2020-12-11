# This class is for Dependency Injection of EventMachine.  All EventMachine interactions should go through here.

require_relative "./tracer"

module ExceptionalSynchrony
  module EMTracing
    def trace_hooks(span:, hooks: {})
      hooks[:on_schedule] = ->(context) {
        context.each { |key, value| span.set_baggage_item(key, value) }
        span.log_kv(event: "scheduled")
      }

      hooks[:on_start] = ->(_context) {
        span.log_kv(event: "started")
      }

      hooks[:on_exception] = ->(_context, ex) {
        span.log_kv(event: "exception", ex_class: ex.class.to_s, ex_message: ex.message)
      }

      hooks[:on_end] = ->(_context) {
        span.log_kv(event: "ended")
      }
    end

    def start_span(span, &blk)
      OpenTracing.scope_manager.activate(span)
      blk.call
    ensure
      OpenTracing.scope_manager.activate(span)
    end
  end
end
