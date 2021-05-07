# frozen_string_literal: true

require "exceptional_synchrony"

require_relative "./work"

module Tracing
  class Factory

    attr_reader :config

    def initialize(config)
      @config    = config
      @random    = Random.new(@config.seed)
      @ex_chance = config.exception_chance
    end

    def build(depth:, parent_operation_name: nil)
      if depth < @config.max_depth
        Work.new(
          self,
          sample_operation_name,
          depth,
          sample_schedule_method,
          {},
          parent_operation_name,
          (sample_exception if rand(100) < @ex_chance)
        )
      end
    end

    private

    def sample_schedule_method
      SCHEDULE_METHODS.sample
    end

    def sample_operation_name
      "#{VERBS.sample}_#{NOUNS.sample}"
    end

    def sample_exception
      RuntimeError.new("#{VERBS.sample}_#{FAILURES.sample}")
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

    FAILURES = [
      "failed", "errored", "blew up", "died", "seg faulted"
    ].freeze
  end
end
