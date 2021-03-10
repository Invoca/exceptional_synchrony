# frozen_string_literal: true

# Monkey patch for the Faraday method that creates the adapter used for a connection.
# If the thread local variable :em_synchrony_reactor_thread is true, it overrides this method
# in order to force use of the :em_synchrony adapter rather than the :net_http adapter.
# This ensures that the Eventmachine reactor does not get blocked by connection i/o.
begin
  require 'faraday'

  module ExceptionalSynchrony
    # Patch built relative to faraday v0.17.3
    module FaradayAdapterPatch_v0
      def adapter(key, *args, &block)

        # BEGIN PATCH
        if key == :net_http && Thread.current.thread_variable_get(:em_synchrony_reactor_thread)
          key = :em_synchrony
        end
        # END PATCH

        use_symbol(Faraday::Adapter, key, *args, &block)
      end
    end

    # Patch built relative to faraday v1.3.0 although the ruby2_keywords prefix
    # was dropped from the adapter method definition to simplify this code
    module FaradayAdapterPatch_v1
      def adapter(klass = NO_ARGUMENT, *args, &block)
        return @adapter if klass == NO_ARGUMENT

        klass = Faraday::Adapter.lookup_middleware(klass) if klass.is_a?(Symbol)

        # BEGIN PATCH
        if klass == Faraday::Adapter::NetHttp && Thread.current.thread_variable_get(:em_synchrony_reactor_thread)
          klass = Faraday::Adapter::EMSynchrony
        end
        # END PATCH

        @adapter = self.class::Handler.new(klass, *args, &block)
      end
    end
  end

  if Faraday::VERSION.start_with?("0")
    Faraday::RackBuilder.prepend ExceptionalSynchrony::FaradayAdapterPatch_v0
  else
    Faraday::RackBuilder.prepend ExceptionalSynchrony::FaradayAdapterPatch_v1
  end

rescue LoadError
  # Monkey patch is not needed if faraday is not available
end
