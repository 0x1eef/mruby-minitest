##
# mruby-minitest -- A lightweight minitest-compatible testing framework
# for mruby. Implements the core API without CRuby stdlib dependencies.
#
# Ported from minitest 5.x by mruby-minitest contributors.
# MIT license.

module Minitest
  VERSION = "5.26.0.mruby1"

  @@after_run = []
  @@installed_at_exit = false
  @extensions = []

  def self.cattr_accessor(name)
    (class << self; self; end).attr_accessor name
  end

  cattr_accessor :seed
  cattr_accessor :backtrace_filter
  cattr_accessor :reporter
  cattr_accessor :extensions
  cattr_accessor :info_signal

  self.info_signal = "INFO"

  ##
  # Registers Minitest to run at process exit using at_exit.
  # Falls back gracefully if at_exit is not available
  # (mruby provides it via mruby-toplevel-ext in the default gembox).
  #
  # You can also call Minitest.run(ARGV) explicitly at the bottom
  # of your test file.
  def self.autorun
    return if @@installed_at_exit
    if respond_to?(:at_exit) || Kernel.respond_to?(:at_exit)
      at_exit {
        next if $! and not ($!.kind_of? SystemExit and $!.success?)
        exit_code = Minitest.run(ARGV)
        @@after_run.reverse_each(&:call)
        exit exit_code || false
      }
      @@installed_at_exit = true
    end
  end

  def self.after_run(&block)
    @@after_run << block
  end

  def self.run(args = [])
    options = process_args(args)
    Minitest.seed = options[:seed]
    srand(Minitest.seed)

    reporter = CompositeReporter.new
    reporter << SummaryReporter.new(options[:io], options)
    reporter << ProgressReporter.new(options[:io], options) unless options[:quiet]

    self.reporter = reporter
    init_plugins(options)
    self.reporter = nil

    reporter.start
    begin
      run_all_suites(reporter, options)
      finished = true
    rescue Interrupt
      warn "Interrupted. Exiting..."
    end

    reporter.report
    @@after_run.reverse_each(&:call)
    return true if finished && reporter.reporters.grep(SummaryReporter).first.count == 0
    finished && reporter.passed?
  end

  def self.process_args(args = [])
    options = { io: $stdout }
    orig = args.dup
    i = 0
    while i < args.length
      case args[i]
      when "--seed", "-s"
        options[:seed] = args[i + 1].to_i; i += 1
      when "--verbose", "-v"
        options[:verbose] = true
      when "--quiet", "-q"
        options[:quiet] = true
      when "--name", "-n"
        options[:include] = args[i + 1]; i += 1
      when "--exclude", "-e"
        options[:exclude] = args[i + 1]; i += 1
      when "--help", "-h"
        puts "minitest [options]"
        puts "  -s, --seed SEED    Sets random seed"
        puts "  -v, --verbose      Verbose. Print each test name as it runs"
        puts "  -q, --quiet        Quiet. Show no dots"
        puts "  -n, --name PATTERN Filter test names (/regexp/ or string)"
        puts "  -e, --exclude PATH Exclude tests (/regexp/ or string)"
        exit 0
      end
      i += 1
    end
    srand
    options[:seed] ||= (ENV["SEED"] || srand).to_i % 0xFFFF
    options[:args] = orig.join(" ")
    options
  end

  def self.run_all_suites(reporter, options)
    Runnable.runnables.shuffle.each { |suite| suite.run_suite(reporter, options) }
  end

  def self.filter_backtrace(bt)
    result = backtrace_filter.filter(bt)
    result.empty? ? bt.dup : result
  end

  def self.clock_time
    Time.now
  end

  ##
  # Exception classes

  class Assertion < Exception
    def result_code
      result_label[0, 1]
    end

    def result_label
      "Failure"
    end

    def location
      bt = Minitest.filter_backtrace(backtrace)
      idx = bt.rindex { |s| s =~ /:in [`'](?:assert|refute|flunk|pass|fail|raise|must|wont)/ }
      loc = bt[idx ? idx + 1 : -1] || "unknown:-1"
      loc.sub(/:in .*$/, "")
    end
  end

  class Skip < Assertion
    def result_label
      "Skipped"
    end
  end

  class UnexpectedError < Assertion
    attr_accessor :error

    def initialize(error)
      super("Unexpected exception")
      self.error = error
    end

    def backtrace
      self.error.backtrace
    end

    def message
      bt = Minitest.filter_backtrace(self.backtrace).join("\n    ")
      "#{self.error.class}: #{self.error.message}\n    #{bt}"
    end

    def result_label
      "Error"
    end
  end

  class UnexpectedWarning < Assertion
    def result_label
      "Warning"
    end
  end

  ##
  # Runnable -- base class for all test-like things

  class Runnable
    attr_accessor :assertions, :failures, :time

    @@runnables = []

    def self.runnables
      @@runnables
    end

    def self.inherited(klass)
      @@runnables << klass
      super
    end

    def self.reset
      @@runnables = []
    end

    def self.methods_matching(re)
      public_instance_methods(true).grep(re).map(&:to_s)
    end

    def self.runnable_methods
      raise NotImplementedError, "subclass responsibility"
    end

    def self.run_order
      :random
    end

    def self.run_suite(reporter, options = {})
      filtered = filter_runnable_methods(options)
      return if filtered.empty?
      filtered.each { |method_name| run(self, method_name, reporter) }
    end

    def self.run(klass, method_name, reporter)
      reporter.prerecord(klass, method_name)
      reporter.record(klass.new(method_name).run)
    end

    def self.filter_runnable_methods(options = {})
      pos = options[:include]
      neg = options[:exclude]
      pos = Regexp.new($1) if pos.is_a?(String) && pos =~ %r{/(.*)/}
      neg = Regexp.new($1) if neg.is_a?(String) && neg =~ %r{/(.*)/}
      runnable_methods
        .select { |m| !pos || pos === m || pos === "#{self}##{m}" }
        .reject { |m| neg && (neg === m || neg === "#{self}##{m}") }
    end

    def name
      @NAME
    end

    def name=(o)
      @NAME = o
    end

    def initialize(name)
      self.name = name
      self.failures = []
      self.assertions = 0
    end

    def run
      raise NotImplementedError, "subclass responsibility"
    end

    def passed?
      raise NotImplementedError, "subclass responsibility"
    end

    def result_code
      raise NotImplementedError, "subclass responsibility"
    end

    def skipped?
      raise NotImplementedError, "subclass responsibility"
    end

    def failure
      self.failures.first
    end

    def time_it
      t0 = Minitest.clock_time
      yield
    ensure
      self.time = Minitest.clock_time - t0
    end
  end

  ##
  # Reportable

  module Reportable
    def passed?
      not self.failure
    end

    def location
      loc = " [#{self.failure.location}]" unless passed? or error?
      "#{self.class_name}##{self.name}#{loc}"
    end

    def class_name
      raise NotImplementedError, "subclass responsibility"
    end

    def result_code
      self.failure && self.failure.result_code || "."
    end

    def skipped?
      self.failure && Skip === self.failure
    end

    def error?
      self.failures.any? { |f| UnexpectedError === f }
    end
  end

  ##
  # Result

  class Result < Runnable
    include Minitest::Reportable
    attr_accessor :klass, :source_location

    def self.from(runnable)
      o = runnable
      r = new(o.name)
      r.klass = o.class.name
      r.assertions = o.assertions
      r.failures = o.failures.dup
      r.time = o.time
      r.source_location = ["unknown", -1]
      r
    end

    def class_name
      self.klass
    end

    def to_s
      return location if passed? and not skipped?
      failures.map { |f| "#{f.result_label}:\n#{self.location}:\n#{f.message}\n" }.join("\n")
    end
  end

  ##
  # BacktraceFilter

  class BacktraceFilter
    attr_accessor :regexp

    def initialize(regexp = /lib\/minitest/)
      self.regexp = regexp
    end

    def filter(bt)
      return ["No backtrace"] unless bt
      new_bt = bt.reject { |line| regexp.match?(line.to_s) }
      new_bt = bt.dup if new_bt.empty?
      new_bt
    end
  end

  self.backtrace_filter = BacktraceFilter.new

  ##
  # Reporters

  class AbstractReporter
    def start; end
    def prerecord(klass, name); end
    def record(result); end
    def report; end
    def passed?; true; end
  end

  class Reporter < AbstractReporter
    attr_accessor :io, :options

    def initialize(io = $stdout, options = {})
      super()
      self.io = io
      self.options = options
    end
  end

  class ProgressReporter < Reporter
    def prerecord(klass, name)
      return unless options[:verbose]
      io.print("%s#%s = " % [klass.name, name])
      io.flush
    end

    def record(result)
      io.print("%.2f s = " % [result.time]) if options[:verbose]
      io.print(result.result_code)
      io.puts if options[:verbose]
    end
  end

  class StatisticsReporter < Reporter
    attr_accessor :assertions, :count, :results
    attr_accessor :start_time, :total_time
    attr_accessor :failures, :errors, :warnings, :skips

    def initialize(io = $stdout, options = {})
      super
      self.assertions = 0
      self.count = 0
      self.results = []
      self.start_time = nil
      self.total_time = nil
      self.failures = nil
      self.errors = nil
      self.warnings = nil
      self.skips = nil
    end

    def passed?
      results.all?(&:skipped?)
    end

    def start
      self.start_time = Minitest.clock_time
    end

    def record(result)
      self.count += 1
      self.assertions += result.assertions
      results << result if not result.passed? or result.skipped?
    end

    def report
      aggregate = {}
      results.each { |r| (aggregate[r.failure.class] ||= []) << r }
      self.total_time = Minitest.clock_time - start_time
      self.failures = (aggregate[Assertion] || []).size
      self.errors = (aggregate[UnexpectedError] || []).size
      self.warnings = (aggregate[UnexpectedWarning] || []).size
      self.skips = (aggregate[Skip] || []).size
    end
  end

  class SummaryReporter < StatisticsReporter
    def start
      super
      io.puts("Run options: #{options[:args]}")
      io.puts
      io.puts("# Running:")
      io.puts
    end

    def report
      super
      io.puts unless options[:verbose]
      io.puts
      io.puts(statistics)
      aggregated_results(io)
      io.puts(summary)
    end

    def statistics
      "Finished in %.6fs, %.4f runs/s, %.4f assertions/s." %
        [total_time, count / total_time, assertions / total_time]
    rescue ZeroDivisionError
      "Finished in %.6fs" % [total_time]
    end

    def aggregated_results(io)
      filtered = results.dup
      filtered.reject!(&:skipped?) unless options[:verbose] || options[:show_skips]
      filtered.each_with_index do |result, i|
        io.puts("\n%3d) %s" % [i + 1, result])
      end
      io.puts
    end

    def summary
      extra = []
      extra << "You have skipped tests. Run with --verbose for details." if
        results.any?(&:skipped?) unless
        options[:verbose] || options[:show_skips]
      "%d runs, %d assertions, %d failures, %d errors, %d skips%s" %
        [count, assertions, failures, errors, skips,
         extra.empty? ? "" : "\n\n#{extra.join}"]
    end
  end

  class CompositeReporter < AbstractReporter
    attr_accessor :reporters

    def initialize(*reporters)
      super()
      self.reporters = reporters
    end

    def <<(reporter)
      self.reporters << reporter
    end

    def passed?
      self.reporters.all?(&:passed?)
    end

    def start
      self.reporters.each(&:start)
    end

    def prerecord(klass, name)
      self.reporters.each { |r| r.prerecord(klass, name) }
    end

    def record(result)
      self.reporters.each { |r| r.record(result) }
    end

    def report
      self.reporters.each(&:report)
    end
  end
end

##
# Assertions module

module Minitest
  module Assertions
    UNDEFINED = Object.new
    def UNDEFINED.inspect; "UNDEFINED"; end

    def assert(test, msg = nil)
      self.assertions += 1
      unless test
        msg ||= "Expected #{mu_pp(test)} to be truthy."
        msg = msg.call if Proc === msg
        raise Minitest::Assertion, msg
      end
      true
    end

    def refute(test, msg = nil)
      msg ||= "Expected #{mu_pp(test)} to not be truthy"
      assert(!test, msg)
    end

    def assert_equal(exp, act, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(exp)} to equal #{mu_pp(act)}" }
      refute_nil(exp, "Use assert_nil if expecting nil") if nil == exp
      assert(exp == act, msg)
    end

    def refute_equal(exp, act, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(act)} to not equal #{mu_pp(exp)}" }
      refute(exp == act, msg)
    end

    def assert_nil(obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to be nil" }
      assert(nil == obj, msg)
    end

    def refute_nil(obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be nil" }
      refute(nil == obj, msg)
    end

    def assert_raises(*exp)
      msg = "#{exp.pop}.\n" if String === exp.last
      exp << StandardError if exp.empty?
      begin
        yield
      rescue *exp => e
        pass
        return e
      rescue Minitest::Assertion
        raise
      rescue SignalException, SystemExit
        raise
      rescue Exception => e
        flunk(proc { exception_details(e, "#{msg}#{mu_pp(exp)} exception expected, not") })
      end
      exp = exp.first if exp.size == 1
      flunk("#{msg}#{mu_pp(exp)} expected but nothing was raised.")
    end

    def assert_in_delta(exp, act, delta = 0.001, msg = nil)
      n = (exp - act).abs
      msg = message(msg) { "Expected |#{exp} - #{act}| (#{n}) to be <= #{delta}" }
      assert(delta >= n, msg)
    end

    def refute_in_delta(exp, act, delta = 0.001, msg = nil)
      n = (exp - act).abs
      msg = message(msg) { "Expected |#{exp} - #{act}| (#{n}) to not be <= #{delta}" }
      refute(delta >= n, msg)
    end

    def assert_in_epsilon(exp, act, epsilon = 0.001, msg = nil)
      assert_in_delta(exp, act, [exp.abs, act.abs].min * epsilon, msg)
    end

    def refute_in_epsilon(exp, act, epsilon = 0.001, msg = nil)
      refute_in_delta(exp, act, [exp.abs, act.abs].min * epsilon, msg)
    end

    def assert_match(matcher, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(matcher)} to match #{mu_pp(obj)}" }
      assert_respond_to(matcher, :=~)
      matcher = Regexp.new(Regexp.escape(matcher)) if String === matcher
      assert(matcher =~ obj, msg)
      $~
    end

    def refute_match(matcher, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(matcher)} to not match #{mu_pp(obj)}" }
      matcher = Regexp.new(Regexp.escape(matcher)) if String === matcher
      refute(matcher =~ obj, msg)
    end

    def assert_includes(collection, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(collection)} to include #{mu_pp(obj)}" }
      assert_operator(collection, :include?, obj, msg)
    end

    def refute_includes(collection, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(collection)} to not include #{mu_pp(obj)}" }
      refute_operator(collection, :include?, obj, msg)
    end

    def assert_instance_of(cls, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to be an instance of #{cls}, not #{obj.class}" }
      assert(obj.instance_of?(cls), msg)
    end

    def refute_instance_of(cls, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be an instance of #{cls}" }
      refute(obj.instance_of?(cls), msg)
    end

    def assert_kind_of(cls, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to be a kind of #{cls}, not #{obj.class}" }
      assert(obj.kind_of?(cls), msg)
    end

    def refute_kind_of(cls, obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be a kind of #{cls}" }
      refute(obj.kind_of?(cls), msg)
    end

    def assert_respond_to(obj, meth, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} (#{obj.class}) to respond to ##{meth}" }
      assert(obj.respond_to?(meth), msg)
    end

    def refute_respond_to(obj, meth, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to not respond to ##{meth}" }
      refute(obj.respond_to?(meth), msg)
    end

    def assert_same(exp, act, msg = nil)
      msg = message(msg) {
        "Expected #{mu_pp(act)} (oid=#{act.object_id}) to be the same as #{mu_pp(exp)} (oid=#{exp.object_id})"
      }
      refute_nil(exp, "Use assert_nil if expecting nil") if nil == exp
      assert(exp.equal?(act), msg)
    end

    def refute_same(exp, act, msg = nil)
      msg = message(msg) {
        "Expected #{mu_pp(act)} (oid=#{act.object_id}) to not be the same as #{mu_pp(exp)} (oid=#{exp.object_id})"
      }
      refute(exp.equal?(act), msg)
    end

    def assert_empty(obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to be empty" }
      assert_predicate(obj, :empty?, msg)
    end

    def refute_empty(obj, msg = nil)
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be empty" }
      refute_predicate(obj, :empty?, msg)
    end

    def assert_predicate(o1, op, msg = nil)
      assert_respond_to(o1, op)
      msg = message(msg) { "Expected #{mu_pp(o1)} to be #{op}" }
      assert(o1.__send__(op), msg)
    end

    def refute_predicate(o1, op, msg = nil)
      assert_respond_to(o1, op)
      msg = message(msg) { "Expected #{mu_pp(o1)} to not be #{op}" }
      refute(o1.__send__(op), msg)
    end

    def assert_operator(o1, op, o2 = UNDEFINED, msg = nil)
      return assert_predicate(o1, op, msg) if UNDEFINED == o2
      assert_respond_to(o1, op)
      msg = message(msg) { "Expected #{mu_pp(o1)} to be #{op} #{mu_pp(o2)}" }
      assert(o1.__send__(op, o2), msg)
    end

    def refute_operator(o1, op, o2 = UNDEFINED, msg = nil)
      return refute_predicate(o1, op, msg) if UNDEFINED == o2
      assert_respond_to(o1, op)
      msg = message(msg) { "Expected #{mu_pp(o1)} to not be #{op} #{mu_pp(o2)}" }
      refute(o1.__send__(op, o2), msg)
    end

    def assert_path_exists(path, msg = nil)
      msg = message(msg) { "Expected path '#{path}' to exist" }
      assert(File.exist?(path), msg)
    end

    def refute_path_exists(path, msg = nil)
      msg = message(msg) { "Expected path '#{path}' to not exist" }
      refute(File.exist?(path), msg)
    end

    def assert_output(stdout = nil, stderr = nil)
      flunk "assert_output requires a block" unless block_given?
      out, err = capture_io { yield }
      assert_equal(stderr, err, "In stderr") if stderr
      assert_equal(stdout, out, "In stdout") if stdout
    end

    def assert_silent
      assert_output("", "") { yield }
    end

    def capture_io
      begin
        captured_stdout = StringIO.new
        captured_stderr = StringIO.new
        orig_stdout, orig_stderr = $stdout, $stderr
        $stdout, $stderr = captured_stdout, captured_stderr
        yield
        return captured_stdout.string, captured_stderr.string
      ensure
        $stdout = orig_stdout
        $stderr = orig_stderr
      end
    end

    def assert_throws(sym, msg = nil)
      default = "Expected #{mu_pp(sym)} to have been thrown"
      caught = true
      value = catch(sym) do
        begin
          yield
        rescue ArgumentError => e
          raise e unless e.message.include?("uncaught throw")
          default += ", not #{e.message.split(/ /).last}"
        end
        caught = false
      end
      assert(caught, msg || default)
      value
    rescue Minitest::Assertion
      raise
    rescue => e
      raise UnexpectedError, e
    end

    def mu_pp(obj)
      obj.inspect
    end

    def message(msg = nil, ending = ".", &default)
      return msg if Proc === msg
      proc {
        custom = "#{msg}.\n" unless nil == msg or msg.to_s.empty?
        "#{custom}#{default.call}#{ending}"
      }
    end

    def pass(_msg = nil)
      assert(true)
    end

    def flunk(msg = nil)
      msg ||= "Epic Fail!"
      assert(false, msg)
    end

    def skip(msg = nil)
      msg ||= "Skipped, no message given"
      raise Minitest::Skip, msg
    end

    def exception_details(e, msg)
      [msg, "Class: <#{e.class}>", "Message: <#{e.message.inspect}>",
       "---Backtrace---", Minitest.filter_backtrace(e.backtrace), "---------------"].join("\n")
    end
  end
end

##
# Test class

module Minitest
  class Test < Runnable
    include Minitest::Reportable
    include Minitest::Assertions

    PASSTHROUGH_EXCEPTIONS = [NoMemoryError, SignalException, SystemExit]
    SETUP_METHODS = %w[before_setup setup after_setup]
    TEARDOWN_METHODS = %w[before_teardown teardown after_teardown]

    def self.runnable_methods
      methods = methods_matching(/^test_/)
      srand(Minitest.seed)
      methods.sort.shuffle
    end

    def self.i_suck_and_my_tests_are_order_dependent!
      class << self
        undef_method :run_order if method_defined?(:run_order)
        define_method(:run_order) { :alpha }
      end
    end

    def run
      time_it do
        capture_exceptions do
          SETUP_METHODS.each { |hook| send(hook) }
          send(self.name)
        end
        TEARDOWN_METHODS.each do |hook|
          capture_exceptions { send(hook) }
        end
      end
      self
    end

    def capture_exceptions
      yield
    rescue *PASSTHROUGH_EXCEPTIONS
      raise
    rescue Minitest::Assertion => e
      self.failures << e
    rescue Exception => e
      self.failures << UnexpectedError.new(e)
    end

    def before_setup; end
    def setup; end
    def after_setup; end
    def before_teardown; end
    def teardown; end
    def after_teardown; end

    def class_name
      self.class.name
    end

    def passed?
      not self.failure
    end

    def result_code
      self.failure && self.failure.result_code || "."
    end

    def skipped?
      self.failure && Skip === self.failure
    end
  end
end

##
# Spec DSL

class Module
  def infect_an_assertion(meth, new_name, dont_flip = false)
    block = dont_flip == :block
    dont_flip = false if block
    module_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{new_name}(*args)
        raise "Calling ##{new_name} outside of test." unless ctx
        case
        when #{!!dont_flip} then
          ctx.#{meth}(target, *args)
        when #{block} && Proc === target then
          ctx.#{meth}(*args, &target)
        else
          ctx.#{meth}(args.first, target, *args[1..-1])
        end
      end
    RUBY
  end
end

module Minitest
  Expectation = Struct.new(:target, :ctx)
end

module Kernel
  def describe(desc, &block)
    cls = Minitest::Spec.create(desc)
    cls.class_eval(&block)
    cls
  end
  private :describe

  def _(value = nil, &block)
    Minitest::Expectation.new(block || value, self)
  end

  alias value _
  alias expect _
end

class Minitest::Spec < Minitest::Test
  module DSL
    def it(desc = "anonymous", &block)
      block ||= proc { skip("(no tests defined)") }
      @specs ||= 0
      @specs += 1
      name = "test_%04d_%s" % [@specs, desc]
      define_method(name, &block)
      name
    end

    alias specify it

    def before(_type = nil, &block)
      define_method(:setup) { super(); instance_eval(&block) }
    end

    def after(_type = nil, &block)
      define_method(:teardown) { instance_eval(&block); super() }
    end

    def let(name, &block)
      name = name.to_s
      define_method(name) {
        @_memoized ||= {}
        @_memoized.fetch(name) { |k| @_memoized[k] = instance_eval(&block) }
      }
    end

    def subject(&block)
      let(:subject, &block)
    end

    def create(desc)
      cls = Class.new(self)
      cls.instance_variable_set(:@desc, desc)
      cls.instance_variable_set(:@name, desc)
      cls
    end

    def name
      defined?(@name) ? @name : super
    end

    alias to_s name
    alias inspect name

    attr_reader :desc
  end

  extend DSL
end

##
# Expectations

module Minitest
  module Expectations
    infect_an_assertion :assert_equal,        :must_equal
    infect_an_assertion :refute_equal,        :wont_equal
    infect_an_assertion :assert_nil,          :must_be_nil
    infect_an_assertion :refute_nil,          :wont_be_nil
    infect_an_assertion :assert_in_delta,     :must_be_within_delta
    infect_an_assertion :refute_in_delta,     :wont_be_within_delta
    infect_an_assertion :assert_match,        :must_match
    infect_an_assertion :refute_match,        :wont_match
    infect_an_assertion :assert_includes,     :must_include
    infect_an_assertion :refute_includes,     :wont_include
    infect_an_assertion :assert_instance_of,  :must_be_instance_of
    infect_an_assertion :refute_instance_of,  :wont_be_instance_of
    infect_an_assertion :assert_kind_of,      :must_be_kind_of
    infect_an_assertion :refute_kind_of,      :wont_be_kind_of
    infect_an_assertion :assert_respond_to,   :must_respond_to
    infect_an_assertion :refute_respond_to,   :wont_respond_to
    infect_an_assertion :assert_same,         :must_be_same_as
    infect_an_assertion :refute_same,         :wont_be_same_as
    infect_an_assertion :assert_empty,        :must_be_empty
    infect_an_assertion :refute_empty,        :wont_be_empty
    infect_an_assertion :assert_predicate,    :must_be,      true
    infect_an_assertion :refute_predicate,    :wont_be,      true
    infect_an_assertion :assert_raises,       :must_raise,   :block
    infect_an_assertion :assert_output,       :must_output,  :block
    infect_an_assertion :assert_silent,       :must_be_silent, :block
  end

  class Expectation
    include Minitest::Expectations
  end
end

##
# Auto-run (works when mruby-toplevel-ext provides at_exit)
Minitest.autorun
