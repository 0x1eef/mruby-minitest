class TestCalculator < Minitest::Test
  def setup
    @calc = 1
  end

  def test_adds
    assert_equal 3, @calc + 2
  end
end

Minitest.run(ARGV)
