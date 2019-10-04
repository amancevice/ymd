require "dotenv/load"
require "aws-sdk-dynamodb"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ymd"

DYNAMODB_ENDPOINT   = ENV["DYNAMODB_ENDPOINT"]   || "http://localhost:8000"
DYNAMODB_TABLE_NAME = ENV["DYNAMODB_TABLE_NAME"] || "Ymd"
DYNAMODB_CLIENT     = Aws::DynamoDB::Client.new endpoint: DYNAMODB_ENDPOINT
DYNAMODB_TABLE      = Aws::DynamoDB::Table.new name:   DYNAMODB_TABLE_NAME,
                                               client: DYNAMODB_CLIENT

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
    begin
      DYNAMODB_CLIENT.create_table({
        attribute_definitions: [
          {
            attribute_name: "Partition",
            attribute_type: "S",
          },
          {
            attribute_name: "Sort",
            attribute_type: "S",
          },
        ],
        key_schema: [
          {
            attribute_name: "Partition",
            key_type: "HASH",
          },
          {
            attribute_name: "Sort",
            key_type: "RANGE",
          },
        ],
        provisioned_throughput: {
          read_capacity_units: 5,
          write_capacity_units: 5,
        },
        table_name: DYNAMODB_TABLE_NAME,
      })
    rescue Aws::DynamoDB::Errors::ResourceInUseException
    end
  end

  desc "Seed DynamoDB"
  task :seed => :create do
    partitions = [
      "ht3jlfaac5lfd6263ulfh4tql8@group.calendar.google.com",
      "en.usa#holiday@group.v.calendar.google.com"
    ]
    items = partitions.map do |partition|
      {Partition: partition, Sort: "CALENDAR~v0"}
    end
    items.map do |item|
      puts "INSERT #{item.to_json}"
      DYNAMODB_TABLE.put_item item: item
    end
  end

  desc "Scan items in DB"
  task :scan do
    DYNAMODB_TABLE.scan.items.map do |item|
      puts item.to_json
    end
  end
end
