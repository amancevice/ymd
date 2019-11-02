require "time"

require "aws-sdk-dynamodb"
require "aws-sdk-dynamodbstreams"

require "ymd/env"

module Ymd
  class Client
    extend Env

    attr_reader :table, :topic, :queue, :stream

    def initialize(table:, topic:, queue:, stream:)
      @table  = table
      @topic  = topic
      @queue  = queue
      @stream = stream
    end

    def shards(options = {})
      options[:stream_arn] ||= @table.latest_stream_arn
      @stream.client.describe_stream(options)&.stream_description&.shards
    end

    def shard_iterator(options = {})
      options[:stream_arn]          ||= @table.latest_stream_arn
      options[:shard_id]            ||= shards(options.slice(:stream_arn)).first.shard_id
      options[:shard_iterator_type] ||= :LATEST
      @stream.client.get_shard_iterator(options)&.shard_iterator
    end
  end
end
