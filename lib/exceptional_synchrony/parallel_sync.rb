require 'fiber'
require 'set'
require 'invoca/utils/hash'

module ExceptionalSynchrony
  class ParallelSync
    def self.parallel(em, *args)
      parallel_sync = new(em, *args)
      yield parallel_sync
      parallel_sync.run_all!
    end

    # em is the EventMachine proxy
    # Downstream is an optional queue.  If provided it will run the job for us.  It must create the Fiber as well.
    def initialize(em, downstream = nil)
      @em = em
      @downstream = downstream
      @jobs = []
      @finished = Set.new
    end

    def add(proc = nil, &block)
      job = proc || block
      @jobs << job
    end

    # Runs all the jobs that have been added.
    # Returns the hash of responses where the key is their ordinal number, in order.
    def run_all!
      original_fiber = Fiber.current

      @responses = (0...@jobs.size).build_hash { |key| [key, nil] } # initialize in sorted order so we don't have to sort later

      @jobs.each_with_index do |job, index|
        run_and_finish = lambda do |*args|
          @responses[index] = CallbackExceptions.return_exception(*args, &job)
          @finished.add(index)
          check_progress(original_fiber)
        end

        if @downstream
          if job.respond_to?(:encapsulate)
            cancel_proc = -> do
              @responses[index] = :cancelled
              @finished.add(index)
            end
            @downstream.add(job.encapsulate(cancel: cancel_proc, &run_and_finish))
          else
            @downstream.add(&run_and_finish)
          end
        else
          Fiber.new(&run_and_finish).resume
        end
      end

      unless finished?
        @yielded = true
        Fiber.yield
      end

      raise_any_exceptions(@responses)

      @responses
    end

  private
    def check_progress(original_fiber)
      if finished? && original_fiber.alive? && original_fiber != Fiber.current && @yielded
        original_fiber.resume
      end
    end

    def finished?
      @finished.size == @jobs.size
    end

    def raise_any_exceptions(responses)
      if (exceptions = responses.values.select { |response| response.is_a?(Exception) }).any?
        master_exception, *remaining_exceptions = exceptions
        remaining_exceptions.each do |ex|
          master_exception.message << "\n====================================\n#{ex.class}: #{ex.to_s}"
        end
        raise master_exception
      end
    end
  end
end
