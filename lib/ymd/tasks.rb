require "ymd/dynamodb"

DYNAMODB_ENDPOINT   = ENV["DYNAMODB_ENDPOINT"]   || "http://localhost:8000"
DYNAMODB_TABLE_NAME = ENV["DYNAMODB_TABLE_NAME"] || "Ymd"

YMD_CLIENT = Ymd::DynamoDB::Client.new name: DYNAMODB_TABLE_NAME, endpoint: DYNAMODB_ENDPOINT

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
          Url:        cal.ical_url,
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
  task :scan, [:limit] do |t,args|
    limit = args[:limit] || "10"
    YMD_CLIENT.table.scan(limit: limit).items.map do |item|
      puts JSON.pretty_generate item
    end
  end

  namespace :query do
    desc "Query partition key"
    task :hash, [:hash,:sort] do |t,args|
      hash = args[:hash]
      sort = args[:sort]
      opts = {
        key_condition_expression:    "#P = :Partition",
        expression_attribute_names:  {"#P" => "Partition"},
        expression_attribute_values: {":Partition" => hash},
      }
      if sort
        opts[:key_condition_expression] << " AND begins_with(#S, :Sort)"
        opts[:expression_attribute_names].update("#S" => ":Sort")
        opts[:expression_attribute_values].update(":Sort" => sort)
      end
      res = YMD_CLIENT.table.query(opts)
      puts JSON.pretty_generate(items: res.items)
    end

    desc "Query sort key"
    task :sort, [:sort,:hash] do |t,args|
      hash = args[:hash]
      sort = args[:sort]
      opts = {
        index_name:                  "SortPartition",
        key_condition_expression:    "#S = :Sort",
        expression_attribute_names:  {"#S" => "Sort"},
        expression_attribute_values: {":Sort" => sort},
      }
      if hash
        opts[:key_condition_expression] << " AND begins_with(#P, :Partition)"
        opts[:expression_attribute_names].update("#P" => ":Partition")
        opts[:expression_attribute_values].update(":Partition" => hash)
      end
      res = YMD_CLIENT.table.query(opts)
      puts JSON.pretty_generate(items: res.items)
    end
  end
end

=begin

| Partition             | Sort                       | Meaning                  |
|:--------------------- |:-------------------------- |:------------------------ |
| @user                 | USER~v0                    | User                     |
| @user                 | SUB~@other/#               | User follow              |
| @user                 | SUB~@other/#calendar       | User follow              |
| @user/*               | CALENDAR~v0                | Feed calendar            |
| @user/*               | FEED~@user/#calendar/event | Feed calendar event      |
| @user/#               | CALENDAR~v0                | Main calendar            |
| @user/#calendar       | CALENDAR~v0                | Secondary calendar       |
| @user/#/event         | EVENT~v0                   | Main calendar event      |
| @user/#calendar/event | EVENT~v0                   | Secondary calendar event |


# Calendar updated process cascade
@acme/#cal         | CALENDAR~v0
└── @acme/#cal/eid | EVENT~v0
    ├──@me/*       | FEED~@acme/#cal/eid
    └──@you/*      | FEED~@acme/#cal/eid

=end
