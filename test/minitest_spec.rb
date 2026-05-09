describe "Array" do
  it "includes elements" do
    _([1, 2, 3]).must_include 2
  end

  it "is empty" do
    _([]).must_be :empty?
  end

  it "excludes elements" do
    _([1, 2, 3]).wont_include 4
  end

  it "is not empty" do
    _([1]).wont_be :empty?
    _([1]).wont_be_empty
  end
end

describe "expectations" do
  it "supports equality and nil checks" do
    _(3).must_equal 3
    _(3).wont_equal 4
    _(nil).must_be_nil
    _("value").wont_be_nil
  end

  it "supports matching" do
    _("mruby-minitest").must_match "mini"
    _("mruby-minitest").wont_match "rspec"
  end

  it "supports type and identity checks" do
    value = "token"
    alias_value = value
    _(value).must_be_instance_of String
    _(value).must_be_kind_of Object
    _(value).must_be_same_as alias_value
    _(1).wont_be_same_as 2
  end

  it "supports respond_to checks" do
    _("abc").must_respond_to :size
    _("abc").wont_respond_to :missing_method
  end

  it "supports numeric delta checks" do
    _(3.1415).must_be_within_delta 3.14, 0.01
    _(3.1415).wont_be_within_delta 3.0, 0.01
  end

  it "supports numeric epsilon checks" do
    assert_in_epsilon 100.0, 100.5, 0.01
    refute_in_epsilon 100.0, 103.0, 0.01
  end

  it "supports empty checks" do
    _("").must_be_empty
    _("content").wont_be_empty
  end

  it "supports operator checks" do
    assert_operator 5, :>, 3
    refute_operator 3, :>, 5
  end

  it "supports raised exception checks" do
    _(proc { raise ArgumentError, "boom" }).must_raise ArgumentError
  end

  it "supports throw checks" do
    value = assert_throws(:done) { throw :done, 42 }
    _(value).must_equal 42
  end

  it "supports output capture" do
    _(proc {
      puts "hello"
      $stderr.puts "warn"
    }).must_output "hello\n", "warn\n"
  end

  it "supports silent blocks" do
    _(proc {
      value = 1 + 1
      _(value).must_equal 2
    }).must_be_silent
  end

  it "supports path checks" do
    assert_path_exists "README.md"
    refute_path_exists "test/does_not_exist.txt"
  end
end

describe "spec DSL" do
  before do
    @events = []
  end

  let(:value) { "memoized" }
  subject { "mruby-minitest" }

  it "supports before, let, and subject" do
    @events << :test
    _(value).must_equal "memoized"
    _(value).must_be_same_as value
    _(subject).must_match "mini"
  end

  after do
    @events << :after
    assert_equal [:test, :after], @events
  end
end

Minitest.run(ARGV)
