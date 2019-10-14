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
    SEEDS.map do |name, seed|
      # seed user
      user = {
        Partition:  name,
        Sort:       "USER~v0",
        CreatedUTC: Time.now.utc.iso8601,
      }
      puts "INSERT #{user.slice(:Partition, :Sort).to_json}"
      YMD_CLIENT.table.put_item(item: user)

      # seed ical
      Icalendar::Calendar.from_google_id(seed).map do |cal|
        ical = {
          Partition:  "#{name}/#",
          Sort:       "ICAL~v0",
          Digest:     cal.to_ical.sha256sum,
          CreatedUTC: Time.now.utc.iso8601,
          "#{cal.ical_name}": {
            CALSCALE: cal.calscale,
            METHOD:   cal.ip_method,
            PRODID:   cal.prodid,
            VERSION:  cal.version,
          },
        }
        puts "INSERT #{ical.slice(:Partition, :Sort).to_json}"
        YMD_CLIENT.table.put_item(item: ical)

        ical.update(Partition:  "#{name}/*")
        puts "INSERT #{ical.slice(:Partition, :Sort).to_json}"
        YMD_CLIENT.table.put_item(item: ical)

        # seed events
        cal.events.map do |event|
          hash = "#{name}/#/#{event.uid}"
          feed = "#{name}/*/#{event.uid}"
          item = {
            Partition:  hash,
            Sort:       "EVENT~v0",
            Digest:     event.to_ical.sha256sum,
            CreatedUTC: Time.now.utc.iso8601,
            "#{event.ical_name}": {},
          }
          puts "INSERT #{item.slice(:Partition, :Sort).to_json}"
          YMD_CLIENT.table.put_item(item: item)

          item.update(Partition: feed, Sort: hash)
          puts "INSERT #{item.slice(:Partition, :Sort).to_json}"
          YMD_CLIENT.table.put_item(item: item)
        end
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

=begin

| Partition             | Sort                  | Meaning                         |
|:--------------------- |:--------------------- |:------------------------------- |
| @user                 | USER~v0               | User                            |
| @user                 | @other/#              | User follow                     |
| @user                 | @other/#calendar      | User follow                     |
| @user/*               | FEED~v0               | Feed calendar (read-only)       |
| @user/*/event         | @user/#calendar/event | Feed calendar event (read-only) |
| @user/#               | CAL~v0                | Main calendar                   |
| @user/#calendar       | CAL~v0                | Secondary calendar              |
| @user/#/event         | EVENT~v0              | Main calendar event             |
| @user/#calendar/event | EVENT~v0              | Secondary calendar event        |

=end
