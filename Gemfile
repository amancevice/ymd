source "https://rubygems.org"

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

gem "aws-sdk-dynamodb",        "~> 1.35"
gem "aws-sdk-dynamodbstreams", "~> 1.15"
gem "aws-sdk-sns",             "~> 1.19"
gem "aws-sdk-sqs",             "~> 1.22"
gem "icalendar-google",        "~> 0.4"

group :development do
  gem "dotenv", "~> 2.7"
  gem "pry",    "~> 0.12"
  gem "rake",   "~> 13.0"
end

group :test do
  gem "rspec", "~> 3.8"
end
