lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "dotenv/load"
require "rspec/core/rake_task"

require "ymd/dynamodb"
require "ymd/tasks"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

DYNAMODB_ENDPOINT   = ENV["DYNAMODB_ENDPOINT"]   || "http://localhost:8000"
DYNAMODB_TABLE_NAME = ENV["DYNAMODB_TABLE_NAME"] || "Ymd"

YMD = Ymd::DynamoDB::Client.new(name: DYNAMODB_TABLE_NAME, endpoint: DYNAMODB_ENDPOINT)
