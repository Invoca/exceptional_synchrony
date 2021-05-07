# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/exporter/jaeger"

require "delegate"

require "exceptional_synchrony"
require "logger"

module Tracing
  class Tracer < Delegator
    class << self
      delegate :configure, to: :instance

      def configure(logger, name, version)
        @instance ||= new(logger, name, version)
      end
    end

    attr_accessor :tracer
    alias_method :__getobj__, :tracer
    alias_method :__setobj__, :tracer

    def initialize(logger, name, version)
      OpenTelemetry::SDK.configure do |c|
        c.service_name = name
        c.service_version = version
        c.logger = logger
        c.add_span_processor jaeger_span_processor("localhost", 14268)
        #c.add_span_processor console_span_processor
        c.error_handler = method(:error_handler)
      end
      @tracer = OpenTelemetry.tracer_provider.tracer(name, version)
      ExceptionalSynchrony::EMP.enable_hooks!
    end

    def trace(operation_name, with_parent: nil, attributes: {}, hooks: {}, &blk)
      span = tracer.start_span(operation_name, with_parent: with_parent)
      attributes.each { |key, val| span.set_attribute(key.to_s, val.inspect) }
      OpenTelemetry::Trace.with_span(span) do |span, context|
        blk.call(span, context)
        yield span, context
      end
    end

    private

    def error_handler(exception: nil, message: nil)
      ExceptionHandling.log_error(exception || message, "OpenTelemetry error: #{message.inspect}")
    end

    def console_span_processor
      OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
        OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter.new
      )
    end

    def jaeger_span_processor(address, port)
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::Jaeger::CollectorExporter.new(endpoint: "http://#{address}:#{port}/api/traces")
      )
    end
  end
end