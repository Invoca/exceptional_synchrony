# frozen_string_literal: true

require "opentracing"
require_relative "./scope"

module ExceptionalSynchrony
  module Tracing
    class ScopeManager < OpenTracing::ScopeManager

      def active
        scopes[active_span_id]
      end

      def activate(span, finish_on_close: true)
        scope = scopes[span.id] || Scope.new(span.tracer, span, finish_on_close)
        scope.activate
        self.active_span_id = span.id
        scope
      end

      def scopes
        Thread.current["tracing:scopes"] ||= {}
      end

      def active_span_id
        Thread.current["tracing:active_span_id"]
      end

      def active_span_id=(value)
        Thread.current["tracing:active_span_id"] = value
      end
    end
  end
end
