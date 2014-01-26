describe ExceptionalSynchrony::CallbackExceptions do
  describe "ensure_callback" do
    it "should execute succeed with return value" do
      deferrable = EM::DefaultDeferrable.new
      mock(deferrable).succeed(42)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        42
      end
    end

    it "should execute succeed by splatting an array return value" do
      deferrable = EM::DefaultDeferrable.new
      mock(deferrable).succeed(41, 42)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        [41, 42]
      end
    end

    it "should execute succeed with a double array when you want to return an array value" do
      deferrable = EM::DefaultDeferrable.new
      mock(deferrable).succeed([41, 42])
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        [[41, 42]]
      end
    end

    it "should execute succeed with the exception that gets raised" do
      deferrable = EM::DefaultDeferrable.new
      exception = ArgumentError.new('Error message')
      mock(deferrable).succeed(exception)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        raise exception
      end
    end

    it "should execute succeed with the exception that gets raised" do
      deferrable = EM::DefaultDeferrable.new
      exception = ArgumentError.new('Error message')
      mock(deferrable).succeed(exception)
      ExceptionalSynchrony::CallbackExceptions.ensure_callback(deferrable) do
        raise exception
      end
    end

    it "should execute succeed even with a Ruby internal exception (not derived from StandardError)" do
      deferrable = EM::DefaultDeferrable.new
      exception = NoMemoryError.new('Error message')
      mock(deferrable).succeed(exception)
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
        result.must_equal 12
      end

      it "should map success values to an array" do
        deferrable = EM::DefaultDeferrable.new
        deferrable.succeed(12, 13, 14)
        result = ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        result.must_equal [12, 13, 14]
      end

      it "should map success exception values to raise" do
        deferrable = EM::DefaultDeferrable.new
        exception = ArgumentError.new("Wrong argument!")
        deferrable.succeed(exception)
        result = assert_raises(ArgumentError) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        result.must_equal exception
      end
    end

    describe "failure" do
      it "should map failure value to raise" do
        deferrable = EM::DefaultDeferrable.new
        deferrable.fail(first: "a", last: "b")
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        result.message.must_equal "{:first=>\"a\", :last=>\"b\"}"
      end

      it "should map failure exceptions to raise" do
        deferrable = EM::DefaultDeferrable.new
        exception = ArgumentError.new("Wrong argument!")
        deferrable.fail(exception)
        result = assert_raises(ExceptionalSynchrony::CallbackExceptions::Failure) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        result.message.must_match /ArgumentError/
        result.message.must_match /Wrong argument!/
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
    end

    describe "no status" do
      it "should raise ArgumentError if you try to map when there is no result yet" do
        deferrable = EM::DefaultDeferrable.new
        result = assert_raises(ArgumentError) do
          ExceptionalSynchrony::CallbackExceptions.map_deferred_result(deferrable)
        end
        result.message.must_match /no deferred status set yet/i
      end
    end
  end

  describe "return_exception" do
    it "should return the value if no exception" do
      ExceptionalSynchrony::CallbackExceptions.return_exception do
        14
      end.must_equal 14
    end

    it "should yield its args" do
      ExceptionalSynchrony::CallbackExceptions.return_exception(0, 1) do |a, b|
        assert_equal [0, 1], [a, b]
        14
      end.must_equal 14
    end

    it "should rescue any exception that was raised and return it" do
      ExceptionalSynchrony::CallbackExceptions.return_exception do
        raise ArgumentError, "An argument error occurred"
      end.inspect.must_equal ArgumentError.new("An argument error occurred").inspect
    end
  end
end
