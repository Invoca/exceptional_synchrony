require_relative '../test_helper'

describe ExceptionalSynchrony::ParallelSync do
  before do
    @em = ExceptionalSynchrony::EventMachineProxy.new(EventMachine, nil)
  end

  it "should run 3 tasks in parallel and return in order" do
    stub_request(:get, "http://www.google.com/").
        to_return(:status => 200, :body => "1", :headers => {})

    stub_request(:get, "http://www.cnn.com/").
        to_return(:status => 402, :body => "2", :headers => {})

    stub_request(:get, "http://news.ycombinator.com/").
        to_return(:status => 200, :body => "3", :headers => {})

    ExceptionalSynchrony::EMP.run_and_stop do
      responses = ExceptionalSynchrony::ParallelSync.parallel(@em) do |parallel|
        parallel.add { @em.sleep(0.001); ExceptionalSynchrony::EMP.connection.new("http://www.google.com").get } # sleep will make this slower
        parallel.add { ExceptionalSynchrony::EMP.connection.new("http://www.cnn.com").get }
        parallel.add { ExceptionalSynchrony::EMP.connection.new("http://news.ycombinator.com").get }
      end

      assert_equal [0, 1, 2], responses.keys

      assert_equal [200, "1"], [responses[0].response_header.status, responses[0].response]
      assert_equal [402, "2"], [responses[1].response_header.status, responses[1].response]
      assert_equal [200, "3"], [responses[2].response_header.status, responses[2].response]
    end
  end

  it "should run 3 non-blocking tasks in parallel and return in order" do
    ExceptionalSynchrony::EMP.run_and_stop do
      responses = ExceptionalSynchrony::ParallelSync.parallel(@em) do |parallel|
        parallel.add { 1 }
        parallel.add { 2 }
        parallel.add { 3 }
      end

      assert_equal [0, 1, 2], responses.keys

      assert_equal 1, responses[0]
      assert_equal 2, responses[1]
      assert_equal 3, responses[2]
    end
  end

  it "should pass an exception through and raise it on the other side" do
    stub_request(:get, "http://www.google.com/").
        to_return(:status => 200, :body => "1", :headers => {})

    stub_request(:get, "http://www.cnn.com/").
        to_return(:status => 200, :body => "2", :headers => {})

    stub_request(:get, "http://news.ycombinator.com/").
        to_return(:status => 200, :body => "3", :headers => {})

    expect(assert_raises(NotImplementedError) do
      ExceptionalSynchrony::EMP.run_and_stop do
        ExceptionalSynchrony::ParallelSync.parallel(@em) do |parallel|
          parallel.add { ExceptionalSynchrony::EMP.connection.new("http://www.google.com").get; raise NotImplementedError, "Not implemented!" }
          parallel.add { ExceptionalSynchrony::EMP.connection.new("http://www.cnn.com").get }
          parallel.add { ExceptionalSynchrony::EMP.connection.new("http://news.ycombinator.com").get }
        end
      end
    end.to_s).must_match(/Not implemented!/)
  end

  it "should pass several exceptions through and raise them on the other side" do
    stub_request(:get, "http://www.google.com/").
        to_return(:status => 200, :body => "1", :headers => {})

    stub_request(:get, "http://www.cnn.com/").
        to_return(:status => 200, :body => "2", :headers => {})

    stub_request(:get, "http://news.ycombinator.com/").
        to_return(:status => 200, :body => "3", :headers => {})

    expect(assert_raises(NotImplementedError) do
      ExceptionalSynchrony::EMP.run_and_stop do
        ExceptionalSynchrony::ParallelSync.parallel(@em) do |parallel|
          parallel.add { ExceptionalSynchrony::EMP.connection.new("http://www.google.com").get; raise NotImplementedError, "Not implemented!" }
          parallel.add { ExceptionalSynchrony::EMP.connection.new("http://www.cnn.com").get; raise LoadError, "A load error occurred" }
          parallel.add { ExceptionalSynchrony::EMP.connection.new("http://news.ycombinator.com").get; raise IndexError, "An index error occurred" }
        end
      end
    end.message).must_match(/Not implemented!.*LoadError: A load error occurred.*IndexError: An index error occurred/m)
  end

  class TestProc
    def initialize(procs = {}, &block)
      @cancel_procs = procs[:cancel]
      @block = block
    end

    def encapsulate(procs = {}, &proc)
      self.class.new(cancel: [procs[:cancel], @cancel_procs].flatten.compact, &proc)
    end

    def call
      @block.call
    end

    def to_proc
      @block
    end

    def cancel
      Array(@cancel_procs).each_with_index { |proc, index| proc.call }
    end
  end

  it "should allow objects to be added instead of Procs" do
    ExceptionalSynchrony::EMP.run_and_stop do
      queue = ExceptionalSynchrony::LimitedWorkQueue.new(@em, 2)

      c = -1
      started2 = nil; ended0 = nil; ended1 = nil
      responses = ExceptionalSynchrony::ParallelSync.parallel(@em, queue) do |parallel|
        parallel.add(TestProc.new { c+=1; @em.sleep(0.001); ended0 = c+=1 })
        parallel.add(TestProc.new { c+=1; @em.sleep(0.005); ended1 = c+=1 })
        parallel.add(TestProc.new { started2 = c+=1; c+=1 })
      end

      assert_equal 5, c
      assert started2 > ended0 || started2 > ended1, [ended0, ended1, started2].inspect

      assert_equal [0, 1, 2], responses.keys
    end
  end

  it "should be composable with LimitedWorkQueue" do
    ExceptionalSynchrony::EMP.run_and_stop do
      queue = ExceptionalSynchrony::LimitedWorkQueue.new(@em, 2)

      c = -1
      started2 = nil; ended0 = nil; ended1 = nil
      responses = ExceptionalSynchrony::ParallelSync.parallel(@em, queue) do |parallel|
        parallel.add { c+=1; @em.sleep(0.001); ended0 = c+=1 }
        parallel.add { c+=1; @em.sleep(0.005); ended1 = c+=1 }
        parallel.add { started2 = c+=1; c+=1 }
      end

      assert_equal 5, c
      assert started2 > ended0 || started2 > ended1, [ended0, ended1, started2].inspect

      assert_equal [0, 1, 2], responses.keys
    end
  end

  class TestProcWithMergeReplace < TestProc
    def merge(queue)
      if same = queue.find { |entry| entry.is_a?(self.class) }
        same.cancel
        queue - [same] + [self]
      end
    end
  end

  it "should be composable with LimitedWorkQueue with an object implementing merge/cancel" do
    ExceptionalSynchrony::EMP.run_and_stop do
      queue = ExceptionalSynchrony::LimitedWorkQueue.new(@em, 2)

      c = 0
      started2 = nil; ended0 = nil; ended1 = nil
      responses = ExceptionalSynchrony::ParallelSync.parallel(@em, queue) do |parallel|
        parallel.add(TestProc.new { c+=1; @em.sleep(0.001); ended0 = c+=2 })
        parallel.add(TestProc.new { c+=4; @em.sleep(0.005); ended1 = c+=8 })
        parallel.add(TestProcWithMergeReplace.new(cancel: -> { c+=16 }) { @em.sleep(0.005); ended1 = c+=32 })
        parallel.add(TestProcWithMergeReplace.new(cancel: -> { c+=64 }) { started2 = c+=128 })
      end

      @em.sleep(0.050)

      assert_equal 1+2+4+8+16+128, c
      assert started2 > ended0 || started2 > ended1, [ended0, ended1, started2].inspect

      assert_equal [0, 1, 2, 3], responses.keys
    end
  end
end
