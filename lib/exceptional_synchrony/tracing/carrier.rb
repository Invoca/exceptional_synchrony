# frozen_string_literal: true

require "opentracing"
require "json"

module ExceptionalSynchrony
  module Tracing
    FORMAT_JSON = 99

    class Carrier < OpenTracing::Carrier
    end
  end
end
