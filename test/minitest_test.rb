class TestArrayAssertions < Minitest::Test
  def setup
    @array = [1, 2, 3]
  end

  def test_includes_elements
    assert_includes @array, 2
  end

  def test_is_empty
    assert_predicate [], :empty?
  end

  def test_excludes_elements
    refute_includes @array, 4
  end

  def test_is_not_empty
    refute_predicate [1], :empty?
    refute_empty [1]
  end
end

class TestAssertions < Minitest::Test
  def test_supports_equality_and_nil_checks
    assert_equal 3, 3
    refute_equal 3, 4
    assert_nil nil
    refute_nil "value"
  end

  def test_supports_matching
    assert_match "mini", "mruby-minitest"
    refute_match "rspec", "mruby-minitest"
  end

  def test_supports_type_and_identity_checks
    value = "token"
    alias_value = value

    assert_instance_of String, value
    assert_kind_of Object, value
    assert_same value, alias_value
    refute_same 1, 2
  end

  def test_supports_respond_to_checks
    assert_respond_to "abc", :size
    refute_respond_to "abc", :missing_method
  end

  def test_supports_numeric_delta_checks
    assert_in_delta 3.14, 3.1415, 0.01
    refute_in_delta 3.0, 3.1415, 0.01
  end

  def test_supports_numeric_epsilon_checks
    assert_in_epsilon 100.0, 100.5, 0.01
    refute_in_epsilon 100.0, 103.0, 0.01
  end

  def test_supports_empty_checks
    assert_empty ""
    refute_empty "content"
  end

  def test_supports_operator_checks
    assert_operator 5, :>, 3
    refute_operator 3, :>, 5
  end

  def test_supports_raised_exception_checks
    assert_raises(ArgumentError) { raise ArgumentError, "boom" }
  end

  def test_supports_throw_checks
    value = assert_throws(:done) { throw :done, 42 }
    assert_equal 42, value
  end

  def test_supports_output_capture
    assert_output("hello\n", "warn\n") do
      puts "hello"
      $stderr.puts "warn"
    end
  end

  def test_supports_silent_blocks
    assert_silent do
      value = 1 + 1
      assert_equal 2, value
    end
  end

  def test_supports_capture_io
    out, err = capture_io do
      print "alpha"
      $stderr.print "beta"
    end

    assert_equal "alpha", out
    assert_equal "beta", err
  end

  def test_supports_path_checks
    assert_path_exists "README.md"
    refute_path_exists "test/does_not_exist.txt"
  end
end

class TestLifecycleHooks < Minitest::Test
  def before_setup
    @events = []
    @events << :before_setup
  end

  def setup
    @events << :setup
  end

  def after_setup
    @events << :after_setup
  end

  def before_teardown
    @events << :before_teardown
  end

  def teardown
    @events << :teardown
  end

  def after_teardown
    @events << :after_teardown
    assert_equal [
      :before_setup,
      :setup,
      :after_setup,
      :test,
      :before_teardown,
      :teardown,
      :after_teardown
    ], @events
  end

  def test_runs_hooks_in_order
    @events << :test
  end
end

Minitest.run(ARGV)
