# frozen_string_literal: true

require "opentracing"

module ExceptionalSynchrony
  module Tracing
    class Tracer < OpenTracing::Tracer

      attr_reader :scope_manager

      def initialize
        @scope_manager = ScopeManager.new(self)
      end

      def start_active_span(operation_name, child_of: nil, references: nil, start_time: Time.now,
                            tags: nil, ignore_active_scope: false, finish_on_close: true)
        # TODO: span should accept more constructor args
        span = Span.new(operation_name: operation_name, tracer: self)
        @scope_manager.activate(span, finish_on_close: finish_on_close).tap do |scope|
          return yield scope if block_given?
        end
      end

      def start_span(operation_name, child_of: nil, references: nil, start_time: Time.now,
                     tags: nil, ignore_active_scope: false)
        span = Span.new(operation_name: operation_name, tracer: self)
        span.start
        yield span if block_given?
        span
      end

      def on_span_close(span)
        ExceptionHandling.log_info("[SPAN] #{span.context.trace_id}:#{span.context.span_id} \"#{span.operation_name}\" (#{span.elapsed_seconds} sec) { logs = #{span.logs.inspect} }", span: span.to_h)
      end

=begin
      def inject(span_context, format, carrier)
        case format
        when FORMAT_JSON
          JSON.parse(span_context).each do |key, value|
            carrier[key] = value
          end
        else
          raise RuntimeError, "unsupported OpenTracing format: #{format.inspect}"
        end
      end

      def extract(format, carrier)
        case format
        when FORMAT_JSON
          # TODO: add baggage
          SpanContext.new(carrier["trace_id"])
        else
          raise RuntimeError, "unsupported OpenTracing format: #{format.inspect}"
        end
      end
=end
    end
  end
end
