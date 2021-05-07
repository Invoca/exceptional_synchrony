# frozen_string_literal: true

require "logger"
require "contextual_logger"

module Tracing
  class Logger < Logger
    include ContextualLogger::LoggerMixin
  end
end
