# frozen_string_literal: true

require "opentelemetry-sdk"

module ExceptionalSynchrony
  module Tracing
    # def configure(service_name:, jaeger_address: nil, jaeger_port: nil)
    #   OpenTelemetry::SDK.configure do |config|
    #     config.service_name = service_name
    #     # Note: can define middleware here, example:
    #     #   config.use 'OpenTelemetry::Instrumentation::Faraday', tracer_middleware: SomeMiddleware
    #     #   config.add_span_processor SpanProcessor.new(SomeExporter.new)
    #     #   etc
    #
    #     # TODO: add jaeger export span processor
    #     #   config.add_span_processor(
    #     #     jaeger_export_processor(service_name, jaeger_address, jaeger_port)
    #     #   )
    #   end
    # end

    # def jaeger_export_prococessor(service_name, address, port)
    #   OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
    #     OpenTelemetry::Exporters::Jaeger::Exporter.new(
    #       service_name: service_name, host: address, port: port
    #     )
    #   )
    # end

    # def context_attributes(context)
    #   (context || {}).reduce({}) do |ctx, (key, value)|
    #     ctx[key.to_s] = value.inspect
    #     ctx
    #   end
    # end
    #
    # def set_trace_hooks!(hooks, span)
    #   hooks[:on_schedule] = Array(hooks[:on_schedule]) <<  ->(context) {
    #     span.add_event("scheduled", attributes: context_attributes(context))
    #   }
    #   hooks[:on_start] = Array(hooks[:on_start]) << ->(context) {
    #     span.add_event("started", attributes: context_attributes(context))
    #   }
    #   hooks[:on_exception] = Array(hooks[:on_exception]) << ->(context, ex) {
    #     exception_context = { "ex_class" => ex.class.to_s, "ex_message" => ex.message }
    #     span.add_event("exception", attributes: context_attributes(exception_context.merge(context || {})))
    #   }
    #   hooks[:on_end] = Array(hooks[:on_end]) << ->(_context) {
    #     span.add_event("ended", attributes: context_attributes(context))
    #   }
    # end
  end
end
