require "time"

require "aws-sdk-dynamodb"
require "aws-sdk-dynamodbstreams"

module Ymd
  module DynamoDB
    class Client
      attr_reader :table, :streams

      def initialize(name:nil, **options)
        options.delete(:endpoint) if options[:endpoint].nil?
        name   ||= "Ymd"
        client   = Aws::DynamoDB::Client.new(options)
        @streams = Aws::DynamoDBStreams::Client.new(options)
        @table   = Aws::DynamoDB::Table.new(name: name, client: client)
      end

      def shards(options = {})
        options[:stream_arn] ||= @table.latest_stream_arn
        @streams.describe_stream(options)&.stream_description&.shards
      end

      def shard_iterator(options = {})
        options[:stream_arn]          ||= @table.latest_stream_arn
        options[:shard_id]            ||= shards(options.slice(:stream_arn)).first.shard_id
        options[:shard_iterator_type] ||= :LATEST
        @streams.get_shard_iterator(options)&.shard_iterator
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
        STDERR.write("PUT #{JSON.pretty_generate(options)}\n")
        @table.put_item(options)
      end

      def query(options = {})
        STDERR.write("QUERY #{JSON.pretty_generate(options)}\n")
        @table.query(options)
      end

      def scan(options = {})
        STDERR.write("SCAN #{JSON.pretty_generate(options)}\n")
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
