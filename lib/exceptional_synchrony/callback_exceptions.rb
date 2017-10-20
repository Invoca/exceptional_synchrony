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
          if result.respond_to?(:error)
             handle_result_error(result)
          else
            raise_failure_for_result(result)
          end
        else
          raise ArgumentError, "No deferred status set yet: #{deferred_status.inspect} #{truncated_inspect(result)}"
        end
      end

      def return_exception(*args)
        begin
          yield *args
        rescue Exception => ex
          ex
        end
      end

      private

      def handle_result_error(result)
        error = result.error
        if error_is_a_timeout?(error)
          raise Timeout::Error
        else
          raise_failure_for_result(result, error: error)
        end
      end

      def raise_failure_for_result(result, error: nil)
        result_string = truncated_inspect(result)
        error_string = if error
                         "ERROR = #{truncated_inspect(error)}; "
                       end
        raise Failure,  "#{error_string}RESULT = #{result_string}"
      end

      def truncated_inspect(obj)
        inspection = obj.inspect[0, 101]
        if inspection.length > 100
          inspection[0, 92] + '...TRUNC'
        else
          inspection
        end
      end

      def error_is_a_timeout?(error)
        error =~ /timeout/i || error == Errno::ETIMEDOUT
      end
    end
  end
end
