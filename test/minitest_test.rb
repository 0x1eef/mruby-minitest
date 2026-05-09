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

  def test_supports_empty_checks
    assert_empty ""
    refute_empty "content"
  end

  def test_supports_raised_exception_checks
    assert_raises(ArgumentError) { raise ArgumentError, "boom" }
  end
end

Minitest.run(ARGV)
