require "rake"

require "ymd/tasks/localstack"
require "ymd/tasks/users"
require "ymd/tasks/subscriptions"

task :pry do
  binding.pry
end
