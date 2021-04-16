# frozen_string_literal: true

require "exceptional_synchrony"

module Tracing
  class Factory

    attr_reader :config

    def initialize(config)
      @config   = config
      @random   = Random.new(@config.seed)
    end

    Work = Struct.new(:factory, :depth, :schedule_method, :schedule_args, :parent_operation_name) do
      def schedule
        ExceptionalSynchrony::EMP.send(schedule_method, **schedule_args) { run }
      end

      def run
        rand(0..factory.config.max_depth).times do
          if (subwork = factory.build(depth: depth + 1, parent_operation_name: schedule_args[:operation_name]))
            subwork.schedule
          end
        end
        ExceptionHandling.log_info("[START #{depth}] #{schedule_args[:operation_name]} (from #{parent_operation_name || 'root'})")
        ExceptionalSynchrony::EMP.sleep(rand(0..5))
        ExceptionHandling.log_info("[END #{depth}]   #{schedule_args[:operation_name]} (from #{parent_operation_name || 'root'})")
      end



      def to_h
        {
          schedule_method: schedule_method,
          schedule_args: schedule_args
        }
      end
    end

    def build(depth:, parent_operation_name: nil)
      if depth < @config.max_depth
        Work.new(
          self,
          depth,
          sample_schedule_method,
          { operation_name: sample_operation_name },
          parent_operation_name
        )
      end
    end

    private

    # def generate_trace_id
    #   Digest::SHA256.hexdigest(@id.to_s)[0..10]
    # end

    def sample_schedule_method
      SCHEDULE_METHODS.sample
    end

    def sample_operation_name
      "#{VERBS.sample}_#{NOUNS.sample}"
    end

    SCHEDULE_METHODS = [
      :next_tick
    ].freeze

    VERBS = [
      "aggregating", "repeating", "subsampling", "defragmenting", "updating", "suppressing",
      "rebooting", "optimizing", "salvaging", "requesting", "introspecting", "handling",
      "asserting", "initializing", "scheduling", "calculating", "receiving", "pausing",
      "counting", "inserting"
    ].freeze

    NOUNS = [
      "network", "disk", "memory", "cpu", "pixels", "drives",
      "sheep", "cows", "pigs", "humans", "mice",
      "chairs"
    ].freeze
  end
end
