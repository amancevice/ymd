require "securerandom"

require "dotenv/load"
require "aws-sdk-dynamodb"
require "icalendar/google"
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

SEEDS = [
  "uqr1emskpd1iochp7r1v8v0nl8@group.calendar.google.com", # TWC
  "ht3jlfaac5lfd6263ulfh4tql8@group.calendar.google.com", # Lunar
  "en.usa#holiday@group.v.calendar.google.com",           # US Holidays
]

class String
  def sha256sum
    Digest::SHA256.hexdigest self
  end
end

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
    SEEDS.each do |seed|
      Icalendar::Calendar.from_google_id(seed).each do |ical|
        ical_id     = SecureRandom.alphanumeric
        ical_digest = Digest::SHA256.hexdigest(ical.to_ical)

        calendar = {
          Partition: ical_id,
          Sort:      "CALENDAR~v0",
          Digest:    ical_digest,
          Url:       ical.ical_url,
        }
        puts "INSERT #{calendar.slice(:Partition, :Sort).to_json}"
        DYNAMODB_TABLE.put_item item: calendar

        listing = {
          Partition: ical_id,
          Sort:      "LISTING~v0",
          Digests:   ical.events.map(&:to_ical).map(&:sha256sum),
        }
        puts "INSERT #{listing.slice(:Partition, :Sort).to_json}"
        DYNAMODB_TABLE.put_item item: listing
      end
    end
  end

  desc "Scan items in DB"
  task :scan do
    DYNAMODB_TABLE.scan.items.map do |item|
      puts item.to_json
    end
  end
end
