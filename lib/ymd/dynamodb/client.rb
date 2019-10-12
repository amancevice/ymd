require "aws-sdk-dynamodb"

module Ymd
  module DynamoDB
    class Client
      attr_reader :table

      def initialize(options = {})
        options.delete(:endpoint) if options[:endpoint].nil?
        name   = options.delete(:name) || "Ymd"
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
  end
end
