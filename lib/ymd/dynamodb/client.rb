require "time"

require "aws-sdk-dynamodb"

module Ymd
  module DynamoDB
    class Client
      attr_reader :table

      def initialize(name:nil, **options)
        options.delete(:endpoint) if options[:endpoint].nil?
        name ||= "Ymd"
        client = Aws::DynamoDB::Client.new(options)
        @table = Aws::DynamoDB::Table.new(name: name, client: client)
      end

      def calendars
        CalendarCollection.new(self)
      end

      def create_table
        @table.client.create_table({
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
          global_secondary_indexes: [
            {
              index_name: "SortPartition",
              key_schema: [
                {
                  attribute_name: "Sort",
                  key_type: "HASH",
                },
                {
                  attribute_name: "Partition",
                  key_type: "RANGE",
                },
              ],
              projection: {
                projection_type: "ALL",
              },
              provisioned_throughput: {
                read_capacity_units: 5,
                write_capacity_units: 5,
              },
            },
          ],
          provisioned_throughput: {
            read_capacity_units: 5,
            write_capacity_units: 5,
          },
          table_name: @table.name,
        })
      rescue Aws::DynamoDB::Errors::ResourceInUseException
      end

      class << self
        def localhost(options = {})
          options[:endpoint] = "http://localhost:8000"
          new(options)
        end
      end
    end

    class CalendarCollection
      include Enumerable

      def initialize(client)
        @client = client
      end

      def each
        @client.table.scan.items.each{|x| yield x }
      end

      def add(calendars)
        calendars.each do |key, cal|
          item = {
            Partition:  "$#{key}",
            Sort:       "#{cal.ical_name}~v0",
            Digest:     cal.to_ical.sha256sum,
            CreatedUTC: Time.now.utc.iso8601,
            "#{cal.ical_name}": {
              CALSCALE: cal.calscale,
              METHOD:   cal.ip_method,
              PRODID:   cal.prodid,
              VERSION:  cal.version,
            },
          }
          puts "INSERT #{item.slice(:Partition, :Sort).to_json}"
          @client.table.put_item(item: item)

          cal.events.each do |event|
            item = {
              Partition:  "##{key}~#{event.uid}",
              Sort:       "#{event.ical_name}~v0",
              Digest:     event.to_ical.sha256sum,
              CreatedUTC: Time.now.utc.iso8601,
              "#{event.ical_name}": {},
            }
            puts "INSERT #{item.slice(:Partition, :Sort).to_json}"
            @client.table.put_item(item: item)
          end
        end
      end
    end
  end
end
