require "time"

require "ymd/dynamodb"
require "ymd/tasks/db"
require "ymd/tasks/api"

DYNAMODB_ENDPOINT   = ENV["DYNAMODB_ENDPOINT"]   || "http://localhost:8000"
DYNAMODB_TABLE_NAME = ENV["DYNAMODB_TABLE_NAME"] || "Ymd"

YMD = Ymd::DynamoDB::Client.new(name: DYNAMODB_TABLE_NAME, endpoint: DYNAMODB_ENDPOINT)
