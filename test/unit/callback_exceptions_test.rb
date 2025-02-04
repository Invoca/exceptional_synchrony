require_relative '../test_helper'
require 'pry'

describe ExceptionalSynchrony::CallbackExceptions do
  describe "ensure_callback" do
    it "should execute succeed with return value" do
      deferrable = EM::DefaultDeferrable.new
      expect(deferrable).to receive(:succeed).with(42)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        42
      end
    end

    it "should execute succeed by splatting an array return value" do
      deferrable = EM::DefaultDeferrable.new
      expect(deferrable).to receive(:succeed).with(41, 42)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        [41, 42]
      end
    end

    it "should execute succeed with a double array when you want to return an array value" do
      deferrable = EM::DefaultDeferrable.new
      expect(deferrable).to receive(:succeed).with([41, 42])
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        [[41, 42]]
      end
    end

    it "should execute succeed with the exception that gets raised" do
      deferrable = EM::DefaultDeferrable.new
      exception = ArgumentError.new('Error message')
      expect(deferrable).to receive(:succeed).with(exception)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        raise exception
      end
    end

    it "should execute succeed with the exception that gets raised" do
      deferrable = EM::DefaultDeferrable.new
      exception = ArgumentError.new('Error message')
      expect(deferrable).to receive(:succeed).with(exception)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        raise exception
      end
    end

    it "should execute succeed even with a Ruby internal exception (not derived from StandardError)" do
      deferrable = EM::DefaultDeferrable.new
      exception = NoMemoryError.new('Error message')
      expect(deferrable).to receive(:succeed).with(exception)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        raise exception
      end
    end
  end

  describe "map_deferred_result" do
    describe "success" do
      it "should map success value" do
        deferrable = EM::DefaultDeferrable.new
        deferrable.succeed(12)
        result = ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        expect(result).must_equal(12)
      end

      it "should map success values to an array" do
        deferrable = EM::DefaultDeferrable.new
        deferrable.succeed(12, 13, 14)
        result = ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        expect(result).must_equal([12, 13, 14])
      end

      it "should map success exception values to raise" do
        deferrable = EM::DefaultDeferrable.new
        exception = ArgumentError.new("Wrong argument!")
        deferrable.succeed(exception)
        result = assert_raises(ArgumentError) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        expect(result).must_equal(exception)
      end
    end

    describe "failure" do
      it "should map failure value to raise" do
        deferrable = EM::DefaultDeferrable.new
        deferrable.fail(first: "a", last: "b")
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end.message
        expect(result).must_equal("RESULT = {:first=>\"a\", :last=>\"b\"}")
      end

      it "should truncate long failures" do
        deferrable = EM::DefaultDeferrable.new
        deferrable.fail('a'*75 + 'b'*75)
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end.message
        expected_message = "RESULT = \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbb...TRUNC"
        expect(result).must_equal(expected_message)
      end

      it "should map failure exceptions to raise" do
        deferrable = EM::DefaultDeferrable.new
        exception = ArgumentError.new("Wrong argument!")
        deferrable.fail(exception)
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end.message
        expect(result).must_match(/ArgumentError/)
        expect(result).must_match(/Wrong argument!/)
      end

      it "should map timeout failure to raise TimeoutError" do
        deferrable = EM::DefaultDeferrable.new

        def deferrable.error
          "Timeout"
        end

        deferrable.fail(deferrable)
        assert_raises(Timeout::Error) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
      end

      it "should map Errno::ETIMEDOUT to TimeoutError" do
        deferrable = EM::DefaultDeferrable.new

        def deferrable.error
          Errno::ETIMEDOUT
        end

        deferrable.fail(deferrable)
        assert_raises(Timeout::Error) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
      end

      it "should map other SystemCallError exceptions to Failures with the error in the message" do
        deferrable = EM::DefaultDeferrable.new

        def deferrable.error
          Errno::ECONNREFUSED
        end

        deferrable.fail(deferrable)
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        expect(result.message).must_match(/\AERROR = Errno::ECONNREFUSED; RESULT = #<EventMachine::DefaultDeferrable/)
      end

      it "should map any other errors to Failure with the error in the message" do
        deferrable = EM::DefaultDeferrable.new

        def deferrable.error
          ArgumentError.new("Some errror")
        end

        deferrable.fail(deferrable)
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        expect(result.message).must_match(/\AERROR = #<ArgumentError: Some errror>; RESULT = #<EventMachine::DefaultDeferrable/)
      end
    end

    describe "no status" do
      it "should raise ArgumentError if you try to map when there is no result yet" do
        deferrable = EM::DefaultDeferrable.new
        result = assert_raises(ArgumentError) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        expect(result.message).must_match(/no deferred status set yet/i)
      end
    end
  end

  describe "return_exception" do
    it "should return the value if no exception" do
      expect(ExceptionalSynchrony::CallbackExceptions.return_exception do
        14
      end).must_equal(14)
    end

    it "should yield its args" do
      expect(ExceptionalSynchrony::CallbackExceptions.return_exception(0, 1) do |a, b|
        assert_equal [0, 1], [a, b]
        14
      end).must_equal(14)
    end

    it "should rescue any exception that was raised and return it" do
      expect(ExceptionalSynchrony::CallbackExceptions.return_exception do
        raise ArgumentError, "An argument error occurred"
      end.inspect).must_equal(ArgumentError.new("An argument error occurred").inspect)
    end
  end
end
