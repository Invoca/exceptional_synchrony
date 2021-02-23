# frozen_string_literal: true

# Monkey patch for the Faraday method that creates the adapter used for a connection.
# If the thread local variable :running_em_synchrony is true, it overrides this method
# in order to force use of the :em_synchrony adapter rather than the :net_http adapter.
# This ensures that the Eventmachine reactor does not get blocked by connection i/o.
begin
  require 'faraday'
  require 'ruby2_keywords'

  module Faraday
    class RackBuilder
      ruby2_keywords def adapter(klass = NO_ARGUMENT, *args, &block)
        return @adapter if klass == NO_ARGUMENT

        klass = Faraday::Adapter.lookup_middleware(klass) if klass.is_a?(Symbol)

        # BEGIN_PATCH
        if klass == Faraday::Adapter::NetHttp && Thread.current.thread_variable_get(:running_em_synchrony)
          klass = Faraday::Adapter::EMSynchrony
        end
        # END_PATCH

        @adapter = self.class::Handler.new(klass, *args, &block)
      end
    end
  end

rescue LoadError
  # Monkey patch is not needed if faraday is not available
end
