require 'rake/testtask'

task :default => :test

task :setup_ext do
  Dir.chdir('ext') do
    system 'ruby extconf.rb'
  end
end

task :build do
  Dir.chdir('ext') do
    system 'rm -f ./*.o'
    system 'rm -f ./*.bundle'
    system 'rm -f ./**/*.o'
    system 'rm -f ./**/*.bundle'
    system 'make'
  end
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :build_test => [:build, :test]

task :build_test do
  
end

task :bench_read do
  Dir.chdir('benchmarks') do
    #system 'ruby reading_amf0.rb'
    system 'ruby reading_amf3.rb'
  end
end

task :bench_write do
  Dir.chdir('benchmarks') do
    system 'ruby writing_amf3.rb'
  end
end

task :bench_readwrite do
  Dir.chdir('benchmarks') do
    system 'ruby readwrite_amf3.rb'
  end
end