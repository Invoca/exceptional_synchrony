# frozen_string_literal: true

require "opentracing"

#require_relative "tracing/carrier"
require_relative "tracing/scope"
require_relative "tracing/scope_manager"
require_relative "tracing/span"
require_relative "tracing/span_context"
require_relative "tracing/tracer"

module ExceptionalSynchrony
  OpenTracing.global_tracer = Tracing::Tracer.new
end
