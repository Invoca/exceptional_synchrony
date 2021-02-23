# frozen_string_literal: true

# Monkey patch for the Faraday method that creates the adapter used for a connection.
# If the thread local variable :running_em_synchrony is true, it overrides this method
# in order to force use of the :em_synchrony adapter rather than the :net_http adapter.
# This ensures that the Eventmachine reactor does not get blocked by connection i/o.
# This patch was built against faraday v0.17 and v1.3, although for v1.3 ruby2_keywords
# usage was dropped in adapter method definition to simplify this code.
begin
  require 'faraday'

  module Faraday
    class RackBuilder
      def adapter(klass = NO_ARGUMENT, *args, &block)
        if Faraday::VERSION[0] == "0"

          # BEGIN PATCH
          key = klass
          if key == :net_http && Thread.current.thread_variable_get(:running_em_synchrony)
            key = :em_synchrony
          end
          # END PATCH

          use_symbol(Faraday::Adapter, key, *args, &block)
        else
          return @adapter if klass == NO_ARGUMENT

          klass = Faraday::Adapter.lookup_middleware(klass) if klass.is_a?(Symbol)

          # BEGIN PATCH
          if klass == Faraday::Adapter::NetHttp && Thread.current.thread_variable_get(:running_em_synchrony)
            klass = Faraday::Adapter::EMSynchrony
          end
          # END PATCH

          @adapter = self.class::Handler.new(klass, *args, &block)
        end
      end
    end
  end

rescue LoadError
  # Monkey patch is not needed if faraday is not available
end
