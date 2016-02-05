describe ExceptionalSynchrony::LimitedWorkQueue do
  before do
    @em = ExceptionalSynchrony::EventMachineProxy.new(EventMachine, EventMachine::HttpRequest)
  end

  it "should raise an exception if created with a limit < 1" do
    assert_raises(ArgumentError) do
      ExceptionalSynchrony::LimitedWorkQueue.new(@em, 0)
    end.message.must_match /must be positive/

    assert_raises(ArgumentError) do
      ExceptionalSynchrony::LimitedWorkQueue.new(@em, -2)
    end.message.must_match /must be positive/
  end

  describe "when created" do
    before do
      @queue = ExceptionalSynchrony::LimitedWorkQueue.new(@em, 2)
    end

    it "should run non-blocking jobs immediately" do
      c = 0
      ExceptionalSynchrony::EMP.run_and_stop do
        @queue.add { c+=1 }
        @queue.add { c+=1 }
        @queue.add { c+=1 }
      end
      assert_equal 3, c
    end

    class LWQTestProc
      def initialize(cancel_proc = nil, &block)
        @cancel_proc = cancel_proc
        @block = block
      end

      def call
        @block.call
      end

      def cancel
        @cancel_proc.call
      end
    end

    it "should allow objects to be queued instead of Procs" do
      c = 0
      ExceptionalSynchrony::EMP.run_and_stop do
        @queue.add(LWQTestProc.new { c+=1 })
        @queue.add(LWQTestProc.new { c+=1 })
        @queue.add(LWQTestProc.new { c+=1 })
      end
      assert_equal 3, c
    end

    class LWQTestProcWithMergeDrop < LWQTestProc
      def merge(queue)
        if queue.find { |entry| entry.is_a?(self.class) }
          self.cancel
          queue # leave it as is (self is dropped)
        end
      end
    end

    it "shouldn't bother with merge when the queue is empty" do
      job_proc = LWQTestProc.new { }
      class << job_proc
        def merge(queue)
          raise "merge should not be called!"
        end
      end

      ExceptionalSynchrony::EMP.run_and_stop do
        @queue.add(job_proc)
      end
    end

    it "should allow objects to merge themselves into the queue (canceling itself)" do
      c = 0
      ExceptionalSynchrony::EMP.run_and_stop do
        @queue.add(LWQTestProc.new { @em.sleep(0.001); c+=1 })
        @queue.add(LWQTestProc.new { @em.sleep(0.001); c+=2 })
        @queue.add(LWQTestProcWithMergeDrop.new(-> { c+=4 }) { @em.sleep(0.001); c+=8 })
        @queue.add(LWQTestProcWithMergeDrop.new(-> { c+=16 }) { @em.sleep(0.001); c+=32 }) # will get merged (by canceling self)
        @em.sleep(0.050)
      end
      assert_equal 1+2+8+16, c
    end

    class LWQTestProcWithMergeReplace < LWQTestProc
      def merge(queue)
        if same = queue.find { |entry| entry.is_a?(self.class) }
          same.cancel
          queue - [same] + [self]
        end
      end
    end

    it "should allow objects to merge themselves into the queue (canceling/replacing earlier)" do
      c = 0
      ExceptionalSynchrony::EMP.run_and_stop do
        @queue.add(LWQTestProc.new { @em.sleep(0.001); c+=1 })
        @queue.add(LWQTestProc.new { @em.sleep(0.001); c+=2 })
        @queue.add(LWQTestProcWithMergeReplace.new(-> { c+=4 }) { @em.sleep(0.001); c+=8 })
        @queue.add(LWQTestProcWithMergeReplace.new(-> { c+=16 }) { @em.sleep(0.001); c+=32 }) # will get merged with above (replacing above)
        @em.sleep(0.050)
      end
      assert_equal 1+2+4+32, c
    end

    it "should run 2 blocking tasks in parallel and only start 3rd when one of the first 2 finishes" do
      stub_request(:get, "http://www.google.com/").
          to_return(:status => 200, :body => "1", :headers => {})

      stub_request(:get, "http://www.cnn.com/").
          to_return(:status => 402, :body => "2", :headers => {})

      stub_request(:get, "http://news.ycombinator.com/").
          to_return(:status => 200, :body => "3", :headers => {})

      ExceptionalSynchrony::EMP.run_and_stop do
        c = -1
        started2 = nil; ended0 = nil; ended1 = nil
        @queue.add { c+=1; @em.sleep(0.001); ExceptionalSynchrony::EMP.connection.new("http://www.google.com").get; ended0 = c+=1 }
        @queue.add { c+=1; @em.sleep(0.001); ExceptionalSynchrony::EMP.connection.new("http://www.cnn.com").get; ended1 = c+=1 }
        @queue.add { started2 = c+=1; ExceptionalSynchrony::EMP.connection.new("http://news.ycombinator.com").get; c+=1 }

        3.times do
          @em.sleep(0.005)
          break if c == 5
        end

        assert_equal 5, c

        assert started2 > ended0 || started2 > ended1, [ended0, ended1, started2].inspect
      end
    end

    describe "add method" do
      it "should not run jobs added to the queue after the queue is paused" do
        @queue.paused = true
        assert_equal true, @queue.paused?
        c = 0
        ExceptionalSynchrony::EMP.run_and_stop do
          3.times { @queue.add { c+=1 } }
        end

        mock(@queue).work!.never
        assert_equal 3, @queue.instance_variable_get("@job_procs").size
        assert_equal 0, c
      end

      it "should run jobs already in queue, before the queue is paused, but should not run jobs added after the pause" do
        c = 0

        ExceptionalSynchrony::EMP.run_and_stop do
          3.times { @queue.add { c+=1 } }
          @em.sleep(0.0750)
          @queue.paused = true
          6.times { @queue.add { c+=2 } }
          @em.sleep(0.0750)
        end

        assert_equal 3, c
        assert_equal 6, @queue.instance_variable_get("@job_procs").size
      end
    end

    describe "when calling #work!" do
      before do
        @queue = ExceptionalSynchrony::LimitedWorkQueue.new(@em, 2)
      end

      it "should run items in queue" do
        c = 0
        job_procs = (0..2).map { Proc.new { c += 1} }

        @queue.instance_variable_set(:@job_procs, job_procs)
        mock.proxy(Fiber).new.with_any_args.times(3)
        @queue.work!

        assert_equal 0, @queue.instance_variable_get("@job_procs").size
        assert_equal 3, c
      end

      it "should run items added to queue, even if queue is paused" do
        @queue.paused = true
        c = 4
        job_procs = (0..2).map { Proc.new { c += 1} }
        @queue.instance_variable_set(:@job_procs, job_procs)
        assert_equal 3, @queue.instance_variable_get("@job_procs").size
        mock.proxy(Fiber).new.with_any_args.times(3)

        @queue.work!

        assert_equal 7, c
        assert_equal 0, @queue.instance_variable_get("@job_procs").size
      end

      it "should not run if queue_empty" do
        stub(@queue).queue_empty? { true }
        c = 0
        job_procs = (0..2).map { Proc.new { c += 1} }
        @queue.instance_variable_set(:@job_procs, job_procs)
        assert_equal 3, @queue.instance_variable_get("@job_procs").size
        mock(Fiber).new.never

        @queue.work!
        assert_equal 0, c
      end

      it "should not run if workers is full" do
        stub(@queue).workers_full? { true }
        c = 0
        job_procs = (0..2).map { Proc.new { c += 1} }
        @queue.instance_variable_set(:@job_procs, job_procs)

        assert_equal 3, @queue.instance_variable_get("@job_procs").size
        mock(Fiber).new.never

        @queue.work!
        assert_equal 0, c
      end

      it "should properly determine if the queue's workers are full" do
        @queue.instance_variable_set(:@worker_count, 20)
        @queue.instance_variable_set(:@limit, 10)

        assert_equal true, @queue.workers_full?

        @queue.instance_variable_set(:@worker_count, 10)
        @queue.instance_variable_set(:@limit, 10)

        assert_equal true, @queue.workers_full?

        @queue.instance_variable_set(:@worker_count, 5)
        @queue.instance_variable_set(:@limit, 10)

        assert_equal false, @queue.workers_full?
      end

      it "should properly determine if the queue is empty" do
        @queue.instance_variable_set(:@job_procs, [])
        assert_equal true, @queue.queue_empty?
        @queue.instance_variable_set(:@job_procs, [Proc.new { "hello"}])
        assert_equal false, @queue.queue_empty?
      end
    end

  end
end
