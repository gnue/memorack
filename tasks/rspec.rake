begin
  require 'rspec'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  require 'rspec'
end
begin
  require 'rspec/core/rake_task'
rescue LoadError
  puts <<-EOS
To use rspec for testing you must install rspec gem:
    gem install rspec
EOS
  exit(0)
end

desc "Run the specs under spec/models"
# SpecTask は使用しない
#Spec::Rake::SpecTask.new do |t|
#  t.spec_opts = ['--options', "spec/spec.opts"]
#  t.spec_files = FileList['spec/**/*_spec.rb']
#end
# 代わりに RakeTask を使用する
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--options=' "spec/spec.opts"]
end
