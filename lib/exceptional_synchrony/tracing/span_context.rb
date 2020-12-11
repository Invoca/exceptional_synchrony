# frozen_string_literal: true

require "ulid"
require "opentracing"

module ExceptionalSynchrony
  module Tracing
    class SpanContext < OpenTracing::SpanContext

      attr_reader :trace_id, :span_id, :baggage

      def initialize(trace_id: nil, baggage: {})
        @trace_id = trace_id || ULID.generate
        @span_id  = ULID.generate
        @baggage  = baggage
      end
    end
  end
end
