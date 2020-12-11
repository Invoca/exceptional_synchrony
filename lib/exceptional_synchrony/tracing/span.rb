# frozen_string_literal: true

require "opentracing"

module ExceptionalSynchrony
  module Tracing
    class Span < OpenTracing::Span
      STATES = [:open, :closed].freeze

      class << self
        private

        @id = 0

        def next_id
          @id += 1
        end
      end

      attr_reader :id, :context

      attr_accessor :operation_name

      def initialize(operation_name:, tracer:, context: nil)
        @id             = self.class.next_id
        @operation_name = operation_name
        @tracer         = tracer
        @context        = context || SpanContext::NOOP_INSTANCE
        @start_time     = nil
        @end_time       = nil
        @tags           = {}
        @logs           = {}
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
        @started_at = start_time || Time.now
      end

      def finish(end_time: Time.now)
        @end_time = end_time || Time.now
      end

      def elapsed_seconds
        if @started_at && @finished_at
          (@finished_at - @started_at).round(3)
        end
      end

      def to_h
        {
          operation_name: @operation_name,
          start_time: @start_time,
          end_time: @end_time,
          elapsed_seconds: elapsed_seconds,
          tags: tags,
          logs: logs.inspect,
          context: @context.to_h
        }
      end
    end
  end
end
