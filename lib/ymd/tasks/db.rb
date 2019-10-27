=begin

| Partition     | Sort          | Meaning                  |
|:------------- |:------------- |:------------------------ |
| @user         | USER~v0       | User                     |
| @user         | SUB~@other/#  | User follow              |
| @user/*       | CALENDAR~v0   | Feed calendar            |
| @user/*       | @user/#/event | Feed calendar event      |
| @user/#       | CALENDAR~v0   | Main calendar            |
| @user/#/event | EVENT~v0      | Main calendar event      |


# Calendar updated
@acme/#         | CALENDAR~v0
├── @acme/#     | CALENDAR~vX
├── @acme/#/eid | EVENT~v0
├── @acme/#/eid | EVENT~v0
├── ...         | ...
└── @acme/#/eid | EVENT~v0

# Event updated
@acme/#/eid     | EVENT~v0
├── @acme/#/eid | EVENT~vX
├── @me/*       | @acme/#/eid
├── ...         | ...
└── @you/*      | @acme/#/eid

=end

SEEDS = {
  "@ymd"        => nil,
  "@BostonTWC"  => "uqr1emskpd1iochp7r1v8v0nl8@group.calendar.google.com", # TWC
  "@themoon"    => "ht3jlfaac5lfd6263ulfh4tql8@group.calendar.google.com", # Lunar
  "@usholidays" => "en.usa#holiday@group.v.calendar.google.com",           # US Holidays
}

namespace :db do
  task :start do
    sh "docker-compose up --detach dynamodb"
  end

  task :stop do
  	sh "docker-compose down"
  end

  desc "Drop DynamoDB table"
  task :drop do
    sh "docker-compose down --volumes"
  end

  desc "Create DynamoDB table"
  task :create => :start do
    YMD.create_table
  end

  desc "Scan items in DynamoDB"
  task :scan, [:limit] do |t, args|
    limit = args[:limit] || "10"
    items = YMD.scan(limit: limit).items
    puts JSON.pretty_generate(items: items)
  end

  namespace :seed do
    task :users do
      SEEDS.keys.each do |name|
        user = {
          Partition:  name,
          Sort:       "USER~v0",
          CreatedUTC: Time.now.utc.iso8601,
        }
        YMD.put_item(item: user)
      end
    end

    task :calendars do
      SEEDS.select{|name, seed| v }.map do |name, seed|
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
          YMD.put_item(item: ical)
        end
      end
    end

    task :events do
      SEEDS.select{|name, seed| v }.map do |name, seed|
        Icalendar::Calendar.from_google_id(seed).map do |cal|
          cal.events.map do |event|
            hash = "#{name}/#/#{event.uid}"
            item = {
              Partition:  hash,
              Sort:       "EVENT~v0",
              Time:       event.dtstart.to_time.utc.iso8601,
              Digest:     event.to_ical.sha256sum,
              CreatedUTC: Time.now.utc.iso8601,
              Body:       event.to_ical,
              "#{event.ical_name}": {},
            }
            YMD.put_item(item: item)

            feed = "#{name}/*"
            item.update(Partition: feed, Sort: hash)
            YMD.put_item(item: item)
          end
        end
      end
    end
  end

  desc "Seed DynamoDB"
  task :seed => [:"seed:users", :"seed:calendars", :"seed:events"]
end
