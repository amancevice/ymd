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
            {
              attribute_name: "Time",
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
          local_secondary_indexes: [
            {
              index_name: "PartitionTime",
              key_schema: [
                {
                  attribute_name: "Partition",
                  key_type: "HASH",
                },
                {
                  attribute_name: "Time",
                  key_type: "RANGE",
                },
              ],
              projection: {
                projection_type: "ALL",
              },
            },
          ],
          provisioned_throughput: {
            read_capacity_units: 5,
            write_capacity_units: 5,
          },
          stream_specification: {
            stream_enabled: true,
            stream_view_type: "NEW_AND_OLD_IMAGES",
          },
          table_name: @table.name,
        })
      rescue Aws::DynamoDB::Errors::ResourceInUseException
      end

      def put_item(options = {})
        puts "PUT #{options.to_json}"
        @table.put_item(options)
      end

      def query(options = {})
        puts "QUERY #{options.to_json}"
        @table.query(options)
      end

      def scan(options = {})
        puts "SCAN #{options.to_json}"
        @table.scan(options)
      end

      class << self
        def localhost(options = {})
          options[:endpoint] = "http://localhost:8000"
          new(options)
        end
      end
    end
  end
end
