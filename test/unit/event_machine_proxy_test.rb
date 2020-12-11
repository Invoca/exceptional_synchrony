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

  before do
    @em = ExceptionalSynchrony::EventMachineProxy.new(EventMachine, nil)
    @yielded_value = nil
    @block = -> (value) { @yielded_value = value }
  end

  it "should proxy add_timer" do
    mock(EventMachine::Synchrony).add_timer(10)
    @em.add_timer(10) { }
  end

  it "should proxy add_periodic_timer" do
    mock(EventMachine::Synchrony).add_periodic_timer(10)
    @em.add_periodic_timer(10) { }
  end

  it "should proxy sleep" do
    mock(EventMachine::Synchrony).sleep(0.001)
    @em.sleep(0.001)
  end

  it "should proxy next_tick" do
    mock(EventMachine::Synchrony).next_tick
    @em.next_tick { }
  end

  it "should proxy stop" do
    mock(EventMachine).stop
    mock(EventMachine).next_tick
    @em.stop
  end

  it "should proxy connect" do
    ServerClass = Class.new
    mock(EventMachine).connect(ServerClass, 8080, :handler, :extra_arg).yields(:called)
    @em.connect(ServerClass, 8080, :handler, :extra_arg, &@block)
    expect(@yielded_value).must_equal(:called)
  end

  describe "#yield_to_reactor" do
    it "should give control to other threads when the reactor is running" do
      mock(@em).reactor_running? { true }
      mock(EventMachine::Synchrony).sleep(0)
      @em.yield_to_reactor
    end

    it "should be a no-op if the reactor is not running" do
      mock(@em).reactor_running? { false }
      stub(EventMachine::Synchrony).sleep(0) { raise "Should not sleep!" }
      @em.yield_to_reactor
    end
  end

  describe "#defer" do
    it "should output its block's output when it doesn't raise an error" do
      ExceptionHandling.logger = Logger.new(STDERR)

      @em.run do
        assert_equal 12, @em.defer("#defer success") { 12 }
        @em.stop
      end
    end

    it "should raise an error when its block raises an error" do
      ExceptionHandling.logger = Logger.new(STDERR)

      @em.run do
        ex = assert_raises(ArgumentError) do
          @em.defer("#defer raising an error") { raise ArgumentError, "!!!" }
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
      mock(ExceptionHandling).log_error(EXCEPTION, "add_timer", {})
      mock(EventMachine::Synchrony).add_timer(10) { |duration, *args| args.first.call }
      @em.add_timer(10) { raise EXCEPTION }
    end

    it "add_periodic_timer" do
      mock(ExceptionHandling).log_error(EXCEPTION, "add_periodic_timer", {})
      mock(EventMachine::Synchrony).add_periodic_timer(10) { |duration, *args| args.first.call }
      @em.add_periodic_timer(10) { raise EXCEPTION }
    end

    it "next_tick" do
      mock(ExceptionHandling).log_error(EXCEPTION, "next_tick", {})
      mock(EventMachine::Synchrony).next_tick { |*args| args.first.call }
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
        [:log, :raise].each do |on_error|
          describe "when using #{method} and on_error = #{on_error}" do
            it "should dispatch to the proxy's synchrony method instead of run iff synchrony" do
              dispatched = false
              assert_equal method, (@proxy.run(on_error: on_error) { dispatched = true })
              assert_equal true, dispatched
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
            mock(ExceptionHandling).log_error(EXCEPTION, "run_with_error_logging", {})

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
    mock(EventMachine).reactor_running?
    @em.reactor_running?
  end

  describe "hooks" do
    before do
      ExceptionHandling.logger = Logger.new(STDERR)
      set_test_const("ExceptionalSynchrony::EventMachineProxy::WRAP_WITH_ENSURE_COMPLETELY_SAFE", true)
      stub(ExceptionHandling).log_info { nil }
    end

    describe "when enabled" do
      before do
        @em.enable_hooks!
      end

      it "calls any registered hooks" do
        events = []
        hooks = {
          on_schedule: ->(ctx) { events << [:on_schedule, ctx] },
          on_start: ->(ctx) { events << [:on_start, ctx] },
          on_exception: ->(ctx, ex) { events << [:on_exception, ctx, ex] },
          on_end: ->(ctx) { events << [:on_end, ctx] }
        }
        ex = ArgumentError.new("nope")
        mock(ExceptionHandling).log_error(ex, "next_tick", {})

        @em.run do
          @em.next_tick(hooks: hooks) do
            raise ex
          end
          @em.stop
        end

        ctx = { schedule_method: :next_tick, schedule_method_args: [] }
        expected = [
          [:on_schedule, ctx],
          [:on_start, ctx],
          [:on_exception, ctx, ex],
          [:on_end, ctx]
        ]
        assert_equal expected, events
      end

      it "allows multiple proces to be registered for the same hook" do
        events = []
        hooks = {
          on_start: [
                      ->(ctx) { events << [:on_start_1, ctx] },
                      ->(ctx) { events << [:on_start_2, ctx] }
                    ]
        }

        @em.run do
          @em.next_tick(hooks: hooks) { nil }
          @em.stop
        end

        ctx = { schedule_method: :next_tick, schedule_method_args: [] }
        expected = [
          [:on_start_1, ctx],
          [:on_start_2, ctx],
        ]
        assert_equal expected, events

      end

      it "should allow hooks to be ignored" do
        events = []
        hooks = {
          on_start: ->(ctx) { events << [:on_start, ctx] },
        }
        ex = ArgumentError.new("nope")
        mock(ExceptionHandling).log_error(ex, "next_tick", {})

        @em.run do
          @em.next_tick(hooks: hooks) do
            raise ex
          end
          @em.stop
        end

        ctx = { schedule_method: :next_tick, schedule_method_args: [] }
        expected = [
          [:on_start, ctx],
        ]
        assert_equal expected, events

      end
    end

    describe "when disabled" do
      before do
        @em.disable_hooks!
      end

      it "succeeds when no hooks are specified" do
        events = []

        @em.run do
          @em.next_tick(hooks: {}) { events << :main }
          @em.stop
        end
        #mock(ExceptionHandling).log_info.with_any_args do |**args|
        #  args
        #end
        assert_equal [:main], events
      end

      it "raises when hooks specified" do
        events = []
        hooks = { on_start: ->(ctx) { events << [:on_start, ctx] } }

        assert_raises ArgumentError, "cannot schedule with hooks when hooks are disabled" do
          @em.next_tick(hooks: hooks) { nil }
        end
      end
    end
  end

  describe "tracing" do
    before do
      ExceptionHandling.logger = Logger.new(STDERR)
      set_test_const("ExceptionalSynchrony::EventMachineProxy::WRAP_WITH_ENSURE_COMPLETELY_SAFE", true)
    end

    describe "with hooks enabled" do
      before do
        @em.enable_hooks!
      end

      it "emits spans" do
        mock(ExceptionHandling).log_info.with(/^\[SPAN\] [A-Z0-9]+\:[A-Z0-9]+/, anything)

        @em.run do
          @em.next_tick { nil }
          @em.stop
        end
      end
    end

    describe "with hooks disabled" do
      before do
        @em.disable_hooks!
      end

      it "doesn't emit spans" do
        dont_allow(ExceptionHandling).log_info.with(/^\[SPAN\] [A-Z0-9]+\:[A-Z0-9]+/, anything)

        @em.run do
          @em.next_tick { nil }
          @em.stop
        end
      end
    end
  end
end
