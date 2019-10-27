lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "dotenv/load"
require "icalendar/google"
require "pry"
require "rspec/core/rake_task"

require "ymd/tasks"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
