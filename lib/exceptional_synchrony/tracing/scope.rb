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

      attr_reader :manager, :span

      def initialize(manager, span, finish_on_close)
        @manager         = manager
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
        @manager.on_scope_close(self)
      end
    end
  end
end