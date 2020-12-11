# frozen_string_literal: true

require "opentracing"

module ExceptionalSynchrony
  module Tracing
    class Scope < OpenTracing::Scope
      STATES = [
        :started,
        :active,
        :inactive,
        :finished
      ].freeze

      attr_reader :tracer, :span

      def initialize(tracer, span, finish_on_close)
        @tracer          = tracer
        @span            = span
        @state           = :started
        @finish_on_close = finish_on_close
      end

      STATES.each do |state|
        define_method("#{state}?") do
          @state == state
        end
      end

      def activate
        @state = :active
      end

      def close
        span.finish if @finish_on_close
      end
    end
  end
end