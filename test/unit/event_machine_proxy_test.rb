require_relative '../test_helper'

describe ExceptionalSynchrony::EventMachineProxy do
  include TestHelper

  before do
    @em = ExceptionalSynchrony::EventMachineProxy.new(EventMachine, nil)
    @yielded_value = nil
    @block = lambda { |value| @yielded_value = value }
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

  it "should have a #yield_to_reactor to give control to other threads" do
    mock(EventMachine::Synchrony).sleep(0)
    @em.yield_to_reactor
  end

  EXCEPTION = ArgumentError.new('in block')

  describe "blocks should be wrapped in ensure_completely_safe" do
    before do
      set_test_const('ExceptionalSynchrony::EventMachineProxy::WRAP_WITH_ENSURE_COMPLETELY_SAFE', true)
    end

    it "add_timer" do
      mock(ExceptionHandling).log_error(EXCEPTION, "add_timer")
      mock(EventMachine::Synchrony).add_timer(10) { |duration, *args| args.first.call }
      @em.add_timer(10) { raise EXCEPTION }
    end

    it "add_periodic_timer" do
      mock(ExceptionHandling).log_error(EXCEPTION, "add_periodic_timer")
      mock(EventMachine::Synchrony).add_periodic_timer(10) { |duration, *args| args.first.call }
      @em.add_periodic_timer(10) { raise EXCEPTION }
    end

    it "next_tick" do
      mock(ExceptionHandling).log_error(EXCEPTION, "next_tick")
      mock(EventMachine::Synchrony).next_tick { |*args| args.first.call }
      @em.next_tick { raise EXCEPTION }
    end
  end

  [false, true].each do |synchrony|
    describe "synchrony = #{synchrony}" do
      it "should dispatch to the proxy's synchrony method instead of run iff synchrony" do
        proxy_mock = Struct.new(:proxy, :class_connection) do
          if synchrony
            def self.synchrony(&block)
              block.(:synchrony)
            end
          end

          def self.run(&block)
            block.(:run)
          end
        end

        mock(proxy_mock).error_handler

        proxy = ExceptionalSynchrony::EventMachineProxy.new(proxy_mock, nil)

        proxy.run(&@block)
        @yielded_value.must_equal synchrony ? :synchrony : :run
      end
    end
  end

  it "should proxy reactor_running?" do
    mock(EventMachine).reactor_running?
    @em.reactor_running?
  end
end
