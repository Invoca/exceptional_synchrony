require_relative '../test_helper'

describe ExceptionalSynchrony::EventMachineProxy do
  include TestHelper

  class RunProxyMock
    def self.run(&block)
      block.call
      :run
    end

    def self.error_handler
    end
  end

  class SynchronyProxyMock < RunProxyMock
    def self.synchrony(&block)
      block.call
      :synchrony
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
    @yielded_value.must_equal :called
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

  describe "run" do
    { synchrony: SynchronyProxyMock, run: RunProxyMock }.each do |method, proxy_mock|
      describe "using #{method}" do
        before do
          @proxy = ExceptionalSynchrony::EventMachineProxy.new(proxy_mock, nil)
        end

        it "should dispatch to the proxy's synchrony method instead of run iff synchrony" do
          dispatched = false
          block = -> { dispatched = true }
          assert_equal method, @proxy.run(&block)
          assert_equal true, dispatched
        end

        it "should rescue any exceptions and raise FatalRunError" do
          block = -> { raise "boom" }
          assert_raises(ExceptionalSynchrony::FatalRunError, "Fatal EventMachine run error") do
            @proxy.run(&block)
          end
        end
      end
    end
  end

  it "should proxy reactor_running?" do
    mock(EventMachine).reactor_running?
    @em.reactor_running?
  end
end
