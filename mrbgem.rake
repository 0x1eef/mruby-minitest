MRuby::Gem::Specification.new("mruby-minitest") do |spec|
  spec.license = "MIT"
  spec.authors = "mruby-minitest contributors"
  spec.version = "0.1.0"
  spec.description = "A lightweight minitest-compatible testing framework for mruby"

  spec.rbfiles = Dir[File.expand_path("mrblib/**/*.rb", __dir__)]

  # at_exit support (autorun). Core gem, already in default gembox.
  spec.add_dependency "mruby-toplevel-ext", :core

  # capture_io / assert_output / assert_silent support.
  # Available from: https://github.com/ksss/mruby-stringio
  spec.add_dependency "mruby-stringio", :github => "ksss/mruby-stringio"
end
