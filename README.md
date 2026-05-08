## About

A lightweight [minitest](https://github.com/minitest/minitest)-compatible
testing framework for mruby. Implements the core minitest API — test
classes, assertions, spec DSL, and expectations — without the heavy CRuby
stdlib dependencies.

## Features

mruby-minitest is an [mrbgem](https://mruby.org/docs/guides/mrbgems.html)
that ports the essential parts of minitest to mruby. It focuses on what
people actually use day-to-day:

- **Minitest::Test** with setup/teardown lifecycle
- **Assertions**: assert_equal, assert_raises, assert_nil, assert_match,
  assert_in_delta, assert_predicate, assert_operator, flunk, skip, pass,
  and all refute_* counterparts
- **Spec DSL**: describe/it blocks, before/after hooks, let/subject
- **Expectations**: must_equal, must_include, must_raise, must_match,
  wont_equal, wont_include, etc.
- **Auto-run** via `at_exit`
- **Reporters**: dot-based progress and summary output

## Example

```ruby
# test/calculator_test.rb
require "minitest"

class TestCalculator < Minitest::Test
  def setup
    @calc = 1
  end

  def test_adds
    assert_equal 3, @calc + 2
  end
end
```

Or spec-style:

```ruby
describe "Array" do
  it "includes elements" do
    _([1, 2, 3]).must_include 2
  end

  it "is empty" do
    _([]).must_be :empty?
  end
end
```

## Integration

Add to your mruby build config:

```ruby
MRuby::Build.new do |conf|
  conf.toolchain
  conf.gembox "default"

  conf.gem "/path/to/mruby-minitest"

  conf.enable_test
end
```

Dependencies are declared in [mrbgem.rake](mrbgem.rake). The only external
dependency is `mruby-stringio` (for `capture_io` / `assert_output`).

## API Coverage

### Included

| Feature | Status |
|---------|--------|
| Minitest::Test with test_* discovery | ✅ |
| setup / teardown lifecycle | ✅ |
| assert / refute | ✅ |
| assert_equal / refute_equal | ✅ |
| assert_nil / refute_nil | ✅ |
| assert_raises | ✅ |
| assert_in_delta / refute_in_delta | ✅ |
| assert_match / refute_match | ✅ |
| assert_includes / refute_includes | ✅ |
| assert_predicate / refute_predicate | ✅ |
| assert_operator / refute_operator | ✅ |
| assert_respond_to / refute_respond_to | ✅ |
| assert_instance_of / refute_instance_of | ✅ |
| assert_kind_of / refute_kind_of | ✅ |
| assert_same / refute_same | ✅ |
| assert_empty / refute_empty | ✅ |
| assert_output / capture_io | ✅ (with stringio) |
| assert_silent | ✅ (with stringio) |
| assert_throws / catch | ✅ |
| skip / flunk / pass | ✅ |
| describe / it / specify | ✅ |
| before / after hooks | ✅ |
| let / subject | ✅ |
| Expectations (must_* / wont_*) | ✅ |
| Minitest.autorun | ✅ |
| SEED / --seed / --verbose / --name | ✅ |
| Guard module (jruby?, mri?, osx?, windows?) | ✅ |

### Not Included

| Feature | Reason |
|---------|--------|
| Parallel execution | No Thread in mruby |
| Diff output | Needs Tempfile + external diff |
| Plugin auto-discovery | No Rubygems |
| INFO signal handler | No Signal/trap in mruby |
| Marshal-based exception sanitization | No Marshal in mruby |
| Bisect / Sprint / Server | Niche features |
| Benchmark | Separate gem (mruby-benchmark exists) |
| Pride output | Pure cosmetic, could add easily |

## License

MIT
