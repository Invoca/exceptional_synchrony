# frozen_string_literal: true

require "opentracing"

module ExceptionalSynchrony
  module Tracing
    class Span < OpenTracing::Span
      STATES = [:open, :closed].freeze

      attr_reader :id, :tracer, :context, :logs, :tags

      attr_accessor :operation_name

      @@id = 0

      def initialize(operation_name:, tracer:, trace_id: nil)
        @id             = (@@id += 1)
        @operation_name = operation_name
        @tracer         = tracer
        @context        = SpanContext.new(trace_id: trace_id)
        @start_time     = nil
        @end_time       = nil
        @tags           = {}
        @logs           = []
      end

      def log_kv(timestamp: nil, **fields)
        @logs << [(timestamp || Time.now).utc.iso8601, fields]
      end

      def set_tag(key, value)
        @tags[key] = value
      end

      def set_baggage_item(key, value)
        @context.set_baggage_item(key, value)
      end

      def get_baggage_item(key)
        @context.get_baggage_item(key)
      end

      def start(start_time: nil)
        @start_time = start_time || Time.now
      end

      def finish(end_time: Time.now)
        @end_time = end_time || Time.now
      end

      def elapsed_seconds
        binding.pry
        if @start_time && @end_time
          (@end_time - @start_time).round(3)
        end
      end

      def to_h
        {
          context: {
            trace_id: context.trace_id,
            span_id: context.span_id,
            baggage: context.baggage
          },
          operation_name: @operation_name,
          start_time: @start_time,
          end_time: @end_time,
          elapsed_seconds: elapsed_seconds,
          tags: tags,
          logs: logs.inspect,
        }
      end
    end
  end
end
