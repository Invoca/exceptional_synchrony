# frozen_string_literal: true

require "exceptional_synchrony"

require_relative "./work"

module Tracing
  class Factory

    attr_reader :config

    def initialize(config)
      @config   = config
      @random   = Random.new(@config.seed)
    end

    def build(depth:, parent_operation_name: nil)
      if depth < @config.max_depth
        Work.new(
          self,
          sample_operation_name,
          depth,
          sample_schedule_method,
          {},
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
