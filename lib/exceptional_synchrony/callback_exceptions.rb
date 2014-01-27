module ExceptionalSynchrony
  module CallbackExceptions
    class Failure < StandardError; end

    class << self
      def ensure_callback(deferrable, &block)
        result = return_exception(&block)
        deferrable.succeed(*Array(result))
      end

      def map_deferred_result(deferrable)
        deferred_status = deferrable.instance_variable_get(:@deferred_status)
        deferred_args = deferrable.instance_variable_get(:@deferred_args)
        result = (deferred_args && deferred_args.size == 1) ? deferred_args.first : deferred_args

        case deferred_status
        when :succeeded
          if result.is_a?(Exception)
            raise result
          else
            result
          end
        when :failed
          if result.respond_to?(:error) && result.error =~ /timeout/i
            raise Timeout::Error
          else
            raise Failure, result.inspect
          end
        else
          raise ArgumentError, "No deferred status set yet: #{deferred_status.inspect} #{result.inspect}"
        end
      end

      def return_exception(*args)
        begin
          yield *args
        rescue Exception => ex
          ex
        end
      end
    end
  end
end
