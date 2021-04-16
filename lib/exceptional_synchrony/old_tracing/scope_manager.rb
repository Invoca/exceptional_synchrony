# frozen_string_literal: true

require "opentracing"
require_relative "./scope"

module ExceptionalSynchrony
  module Tracing
    class ScopeManager < OpenTracing::ScopeManager

      def initialize(tracer)
        @tracer = tracer
      end

      def active
        scopes[active_span_id]
      end

      def activate(span, finish_on_close: true)
        scope = (scopes[span.id] ||= Scope.new(self, span, finish_on_close))
        scope.activate
        self.active_span_id = span.id
        yield scope if block_given?
        ExceptionHandling.log_info("ScopeManager(#{object_id}): Activating scope for #{span.id}. Current = #{scopes.keys.inspect}. Active = #{active_span_id}")
        scope
      end

      def on_scope_close(scope)
        remove_scope(scope.span.id)
        @tracer.on_span_close(scope.span)
      end

      def deactivate
        self.active_span_id = nil
        ExceptionHandling.log_info("ScopeManager(#{object_id}): De-activated active scope")
      end

      def scopes
        Thread.current["tracing:scopes"] ||= {}
      end

      private

      def remove_scope(span_id)
        deactivate if active_span_id == span_id
        scopes.delete(span_id)
        ExceptionHandling.log_info("ScopeManager(#{object_id}): Removed scope for #{span_id}. Current = #{scopes.keys.inspect}. Active = #{active_span_id}")
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
