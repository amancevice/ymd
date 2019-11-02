require "aws-sdk-dynamodb"
require "aws-sdk-dynamodbstreams"
require "aws-sdk-sns"
require "aws-sdk-sqs"

Aws.config = {logger: Logger.new(STDERR)}

module Ymd
  module Env
    def env
      aws_account_id = ENV["AWS_ACCOUNT_ID"]
      aws_region     = ENV["AWS_DEFAULT_REGION"] || ENV["AWS_REGION"] || "us-east-1"

      dynamodb_endpoint   = ENV["DYNAMODB_ENDPOINT"]   || "https://dynamodb.#{aws_region}.amazonaws.com"
      dynamodb_table_name = ENV["DYNAMODB_TABLE_NAME"] || "Ymd"

      sns_endpoint  = ENV["SNS_ENDPOINT"]  || "https://sns.#{aws_region}.amazonaws.com"
      sns_topic_arn = ENV["SNS_TOPIC_ARN"] || "arn:aws:sns:#{aws_region}:#{aws_account_id}:#{dynamodb_table_name}Streams"

      sqs_endpoint  = ENV["SQS_ENDPOINT"]  || "https://sqs.#{aws_region}.amazonaws.com"
      sqs_queue_url = ENV["SQS_QUEUE_URL"] || "http://#{sqs_endpoint}/queue/#{dynamodb_table_name}Streams"

      dynamodb        = Aws::DynamoDB::Client.new(endpoint: dynamodb_endpoint)
      dynamodbstreams = Aws::DynamoDBStreams::Client.new(endpoint: dynamodb_endpoint)
      sns             = Aws::SNS::Client.new(endpoint: sns_endpoint)
      sqs             = Aws::SQS::Client.new(endpoint: sqs_endpoint)

      table  = Aws::DynamoDB::Table.new(name: dynamodb_table_name, client: dynamodb)
      topic  = Aws::SNS::Topic.new(arn: sns_topic_arn, client: sns)
      queue  = Aws::SQS::Queue.new(url: sqs_queue_url, client: sqs)
      stream = Aws::DynamoDBStreams::Resource.new(client: dynamodbstreams)

      new(table: table, topic: topic, queue: queue, stream: stream)
    end
  end
end
