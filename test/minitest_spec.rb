describe "Array" do
  it "includes elements" do
    skip "fixme"
    ([1, 2, 3]).must_include 2
  end

  it "is empty" do
    _([]).must_be :empty?
  end
end

Minitest.run(ARGV)
