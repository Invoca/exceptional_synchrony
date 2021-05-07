# frozen_string_literal: true

require_relative "./factory"
require_relative "./app"
require "exceptional_synchrony"

module Tracing
  class Work
    attr_reader :factory, :depth, :operation_name, :schedule_method, :schedule_args, :parent_operation_name, :exception

    def initialize(factory, operation_name, depth, schedule_method, schedule_args, parent_operation_name, exception)
      @factory               = factory
      @operation_name        = operation_name
      @depth                 = depth
      @schedule_method       = schedule_method
      @schedule_args         = schedule_args
      @parent_operation_name = parent_operation_name
      @exception             = exception
    end

    def schedule(trace: false, parent_context: nil)
      if trace
        with_tracing(parent_context) { |span| em_schedule(span) }
      else
        em_schedule
      end
    end

    def with_tracing(parent_context, &blk)
      App.trace(
        operation_name,
        with_parent: parent_context,
        attributes: {
          schedule_method: schedule_method,
          **schedule_args,
          depth: depth,
          parent_operation_name: parent_operation_name || "root",
        }
      ) do |span, _context|
        blk.call(span)
      end
    end

    def run(span = nil)
      raise @exception if exception
      rand(0..factory.config.max_depth).times do
        if (subwork = factory.build(depth: depth + 1, parent_operation_name: operation_name))
          parent_context = span ? OpenTelemetry::Trace.context_with_span(span) : nil
          subwork.schedule(trace: true, parent_context: parent_context)
        end
      end
      ExceptionHandling.log_info("[START #{depth}] #{schedule_args[:operation_name]} (from #{parent_operation_name || 'root'})")
      ExceptionalSynchrony::EMP.sleep(rand(0..5))
      ExceptionHandling.log_info("[END #{depth}]   #{schedule_args[:operation_name]} (from #{parent_operation_name || 'root'})")
    end

    def em_schedule(span = nil)
      ExceptionalSynchrony::EMP.send(schedule_method, **schedule_args, span: span) { run(span) }
    end

    def to_h
      {
        schedule_method: schedule_method,
        schedule_args: schedule_args
      }
    end
  end
end