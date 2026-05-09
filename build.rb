MRuby::Build.new do |conf|
  conf.toolchain
  conf.gembox "default"
  conf.gem "."
  conf.enable_test
  conf.enable_debug
end
