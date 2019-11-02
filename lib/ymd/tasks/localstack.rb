require "rake"

require "ymd/client"

namespace :localstack do
  desc "Start localstack"
  task :start do
    sh "docker-compose up --detach localstack"
  end

  desc "Stop localstack"
  task :stop do
    sh "docker-compose down"
  end

  desc "Drop localstack"
  task :drop do
    sh "docker-compose down --volumes"
  end

  namespace :bootstrap do
    task :connect => [:start] do
      @ymd = Ymd::Client.env
    end

    namespace :dynamodb do
      task :create_table => [:connect] do
        @ymd.table.client.create_table({
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
          table_name: @ymd.table.name,
        })
      end
    end

    namespace :sqs do
      task :create_queue => [:connect] do
        @ymd.queue.client.create_queue(queue_name: @ymd.queue.url.split(/\//).last)
      end
    end

    namespace :sns do
      task :create_topic => [:connect] do
        @ymd.topic.client.create_topic(name: @ymd.topic.arn.split(/:/).last)
      end

      task :subscribe_queue => [:connect] do
        @ymd.topic.subscribe(protocol: "sqs", endpoint: @ymd.queue.url)
      end
    end
  end

  desc "Bootstrap localstack"
  task :bootstrap => [
    :"bootstrap:dynamodb:create_table",
    :"bootstrap:sqs:create_queue",
    :"bootstrap:sns:create_topic",
    :"bootstrap:sns:subscribe_queue",
  ]
end
