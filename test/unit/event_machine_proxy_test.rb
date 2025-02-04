require_relative '../test_helper'

describe ExceptionalSynchrony::EventMachineProxy do
  include TestHelper

  class RunProxyMock
    class << self
      def run(&block)
        block.call
        :run
      end

      def error_handler
      end
    end
  end

  class SynchronyProxyMock < RunProxyMock
    class << self
      def synchrony(&block)
        block.call
        :synchrony
      end
    end
  end

  def stop_em_after_defers_finish!(em)
    check_finished_counter = 0
    em.add_periodic_timer(0.1) do
      (check_finished_counter += 1) > 20 and raise "defer never finished!"
      em.defers_finished? and em.stop
    end
  end

  before do
    @em = ExceptionalSynchrony::EventMachineProxy.new(EventMachine, nil)
    @yielded_value = nil
    @block = -> (value) { @yielded_value = value }
  end

  it "should proxy add_timer" do
    expect(EventMachine::Synchrony).to receive(:add_timer).with(10)
    @em.add_timer(10) { }
  end

  it "should proxy add_periodic_timer" do
    expect(EventMachine::Synchrony).to receive(:add_periodic_timer).with(10)
    @em.add_periodic_timer(10) { }
  end

  it "should proxy sleep" do
    expect(EventMachine::Synchrony).to receive(:sleep).with(0.001)
    @em.sleep(0.001)
  end

  it "should proxy next_tick" do
    expect(EventMachine::Synchrony).to receive(:next_tick)
    @em.next_tick { }
  end

  it "should proxy stop" do
    expect(EventMachine).to receive(:stop)
    expect(EventMachine).to receive(:next_tick)
    @em.stop
  end

  it "should set thread variable :em_synchrony_reactor_thread running to false when stop" do
    @em.run do
      assert_equal true, Thread.current.thread_variable_get(:em_synchrony_reactor_thread)
      @em.stop
      assert_equal false, Thread.current.thread_variable_get(:em_synchrony_reactor_thread)
    end
  end

  it "should proxy connect" do
    ServerClass = Class.new
    expect(EventMachine).to receive(:connect).with(ServerClass, 8080, :handler, :extra_arg).and_yield(:called)
    @em.connect(ServerClass, 8080, :handler, :extra_arg, &@block)
    expect(@yielded_value).must_equal(:called)
  end

  describe "#yield_to_reactor" do
    it "should give control to other threads when the reactor is running" do
      expect(@em).to receive(:reactor_running?) { true }
      expect(EventMachine::Synchrony).to receive(:sleep).with(0)
      @em.yield_to_reactor
    end

    it "should be a no-op if the reactor is not running" do
      expect(@em).to receive(:reactor_running?) { false }
      allow(EventMachine::Synchrony).to receive(:sleep).with(0).and_raise("Should not sleep!")
      @em.yield_to_reactor
    end
  end

  describe "#defer" do
    before do
      logger = Logger.new(STDERR)
      logger.extend ContextualLogger::LoggerMixin
      ExceptionHandling.logger = logger
    end

    it "should output its block's output when it doesn't raise an error, by default" do
      @em.run do
        assert_equal 12, @em.defer { 12 }
        @em.stop
      end
    end

    it "should not wait for its block to run if option is passed" do
      @block_ran = false

      @em.run do
        assert_nil @em.defer(wait_for_result: false) { @block_ran = true; 12 }
        refute @block_ran
        stop_em_after_defers_finish!(@em)
      end

      assert @block_ran
    end

    it "should handle exceptions when not waiting for its block to run" do
      expect(ExceptionHandling).to receive(:log_error).with(kind_of(RuntimeError), "defer")

      @em.run do
        assert_nil @em.defer(wait_for_result: false) { raise RuntimeError, "error in defer" }
        stop_em_after_defers_finish!(@em)
      end
    end

    it "should raise an error when its block raises an error" do
      @em.run do
        ex = assert_raises(ArgumentError) do
          @em.defer { raise ArgumentError, "!!!" }
        end

        assert_equal "!!!", ex.message
        @em.stop
      end
    end
  end

  EXCEPTION = ArgumentError.new('in block')

  describe "blocks should be wrapped in ensure_completely_safe" do
    before do
      set_test_const('ExceptionalSynchrony::EventMachineProxy::WRAP_WITH_ENSURE_COMPLETELY_SAFE', true)
    end

    it "add_timer" do
      expect(ExceptionHandling).to receive(:log_error).with(EXCEPTION, "add_timer")
      expect(EventMachine::Synchrony).to receive(:add_timer).with(10).and_wrap_original { |_m, duration, &block| block.call }
      @em.add_timer(10) { raise EXCEPTION }
    end

    it "add_periodic_timer" do
      expect(ExceptionHandling).to receive(:log_error).with(EXCEPTION, "add_periodic_timer")
      expect(EventMachine::Synchrony).to receive(:add_periodic_timer).with(10).and_wrap_original { |_m, duration, &block| block.call }
      @em.add_periodic_timer(10) { raise EXCEPTION }
    end

    it "next_tick" do
      expect(ExceptionHandling).to receive(:log_error).with(EXCEPTION, "next_tick")
      expect(EventMachine::Synchrony).to receive(:next_tick).and_wrap_original { |_m, &block| block.call }
      @em.next_tick { raise EXCEPTION }
    end
  end

  { synchrony: SynchronyProxyMock, run: RunProxyMock }.each do |method, proxy_mock|
    describe "run" do
      before do
        @proxy = ExceptionalSynchrony::EventMachineProxy.new(proxy_mock, nil)
      end

      it "should raise ArgumentError if on_error has invalid value" do
        assert_raises(ArgumentError, "Invalid on_error: :ignore, must be :log or :raise") do
          @proxy.run(on_error: :ignore)
        end
      end

      describe "without error" do
        before do
          Thread.current.thread_variable_set(:em_synchrony_reactor_thread, nil)
        end

        [:log, :raise].each do |on_error|
          describe "when using #{method} and on_error = #{on_error}" do
            it "should dispatch to the proxy's synchrony method instead of run iff synchrony" do
              dispatched = false
              assert_equal method, (@proxy.run(on_error: on_error) { dispatched = true })
              assert_equal true, dispatched
            end

            if method == :synchrony
              it "should set thread variable :em_synchrony_reactor_thread running to true" do
                assert_nil Thread.current.thread_variable_get(:em_synchrony_reactor_thread)
                @proxy.run(on_error: on_error) do
                  assert_equal true, Thread.current.thread_variable_get(:em_synchrony_reactor_thread)
                end
              end
            end
          end
        end
      end

      describe "with error" do
        before do
          set_test_const('ExceptionalSynchrony::EventMachineProxy::WRAP_WITH_ENSURE_COMPLETELY_SAFE', true)
        end

        describe "when using #{method} and on_error = :log" do
          it "should rescue any exceptions and log them" do
            expect(ExceptionHandling).to receive(:log_error).with(EXCEPTION, "run_with_error_logging")

            @proxy.run(on_error: :log) { raise EXCEPTION }
          end
        end

        describe "when using #{method} and on_error = :raise" do
          it "should rescue any exceptions and raise FatalRunError" do
            assert_raises(ExceptionalSynchrony::FatalRunError, "Fatal EventMachine run error") do
              @proxy.run(on_error: :raise) { raise EXCEPTION }
            end
          end
        end
      end
    end
  end

  it "should proxy reactor_running?" do
    expect(EventMachine).to receive(:reactor_running?)
    @em.reactor_running?
  end
end
