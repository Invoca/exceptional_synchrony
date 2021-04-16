# frozen_string_literal: true

require "opentelemetry-sdk"

module ExceptionalSynchrony
  module Tracing
    def configure(service_name:, jaeger_address: nil, jaeger_port: nil)
      OpenTelemetry::SDK.configure do |config|
        config.service_name = service_name
        # Note: can define middleware here, example:
        #   config.use 'OpenTelemetry::Instrumentation::Faraday', tracer_middleware: SomeMiddleware
        #   config.add_span_processor SpanProcessor.new(SomeExporter.new)
        #   etc

        # TODO: add jaeger export span processor
        #   config.add_span_processor(
        #     jaeger_export_processor(service_name, jaeger_address, jaeger_port)
        #   )
      end
    end

    # def jaeger_export_prococessor(service_name, address, port)
    #   OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
    #     OpenTelemetry::Exporters::Jaeger::Exporter.new(
    #       service_name: service_name, host: address, port: port
    #     )
    #   )
    # end

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
