require "dotenv/load"
require "icalendar/google"
require "rspec/core/rake_task"

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ymd/dynamodb"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

DYNAMODB_ENDPOINT   = ENV["DYNAMODB_ENDPOINT"]   || "http://localhost:8000"
DYNAMODB_TABLE_NAME = ENV["DYNAMODB_TABLE_NAME"] || "Ymd"
YMD_CLIENT          = Ymd::DynamoDB::Client.new name:     DYNAMODB_TABLE_NAME,
                                                endpoint: DYNAMODB_ENDPOINT

SEEDS = {
  "@bostontwc" => "uqr1emskpd1iochp7r1v8v0nl8@group.calendar.google.com", # TWC
  "@themoon"   => "ht3jlfaac5lfd6263ulfh4tql8@group.calendar.google.com", # Lunar
  "@usolidays" => "en.usa#holiday@group.v.calendar.google.com",           # US Holidays
}

namespace :db do
  desc "Start DynamoDB container"
  task :start do
    sh "docker-compose up --detach dynamodb"
  end

  desc "Stop DynamoDB container"
  task :stop do
  	sh "docker-compose down"
  end

  desc "Drop DynamoDB table"
  task :drop do
    sh "docker-compose down --volumes"
  end

  desc "Create DynamoDB table"
  task :create => :start do
    YMD_CLIENT.create_table
  end

  desc "Seed DynamoDB"
  task :seed => :create do
    SEEDS.map do |user, seed|
      Icalendar::Calendar.from_google_id(seed).map do |ical|
        YMD_CLIENT.calendars.add(seed => ical)
      end
    end
  end

  desc "Scan items in DB"
  task :scan do
    YMD_CLIENT.table.scan.items.map do |item|
      puts JSON.pretty_generate item
    end
  end
end
