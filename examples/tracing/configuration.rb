# frozen_string_literal: true

require "optparse"

module Tracing
  class Configuration
    class << self
      def parse!
        options = {}
        OptionParser.new do |opts|
          opts.banner = "Usage: run [options]"
          opts.on("-v", "--[no-]verbose", TrueClass, "Run verbosely") { |v| options[:verbose] = v }
          opts.on("-D", "--max-depth [NUM]", Integer, "Maximum fiber depth") { |d| options[:max_depth] = d }
          opts.on("-B", "--max-breadth [NUM]", Integer, "Maximum fiber breadth") { |b| options[:max_breadth] = b }
          opts.on("-R", "--max-runtime-seconds [NUM]", Integer, "Maximum runtime in seconds") { |b| options[:max_runtime_seconds] = b }
        end.parse!
        new(options)
      end
    end

    attr_reader :verbose, :max_depth, :max_breadth, :max_runtime_seconds

    def initialize(options)
      @verbose             = !!options[:verbose]
      @max_depth           = options[:max_depth] || 3
      @max_breadth         = options[:max_breadth] || 3
      @max_runtime_seconds = options[:max_runtime_seconds] || 60
    end

    def to_h
      {
        verbose: verbose,
        max_depth: max_depth,
        max_breadth: max_breadth,
        max_runtime_seconds: max_runtime_seconds
      }.inspect
    end
  end
end