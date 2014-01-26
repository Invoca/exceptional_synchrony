module PNAPI
  module Util
    class LimitedWorkQueue
      def initialize(em, limit)
        @em = em
        limit > 0 or raise ArgumentError, "limit must be positive"
        @limit = limit
        @worker_count = 0
        @job_procs = []
      end

      # Adds a job_proc to work.
      def add(proc = nil, &block)
        job = proc || block
        job.respond_to?(:call) or raise "Must respond_to?(:call)! #{job.inspect}"
        if @job_procs.any? && job.respond_to?(:merge) && (merged_queue = job.merge(@job_procs))
          @job_procs = merged_queue
        else
          @job_procs << job
        end
        work!
      end

      def workers_empty?
        @worker_count.zero?
      end

      def workers_full?
        @worker_count >= @limit
      end

      def queue_empty?
        @job_procs.empty?
      end

      private
      def work!
        until queue_empty? || workers_full?
          job_proc = @job_procs.shift
          @worker_count += 1
          Fiber.new do
            job_proc.call
            worker_done
          end.resume
        end
      end

      def worker_done
        @worker_count -= 1
        work!
      end
    end
  end
end
