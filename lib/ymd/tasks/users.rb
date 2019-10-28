require "time"

namespace :users do
  desc "List users"
  task :list do
    res = YMD.query(
      index_name:                  "SortPartition",
      key_condition_expression:    "#S = :Sort AND begins_with(#P, :Partition)",
      expression_attribute_names:  {"#S" => "Sort", "#P" => "Partition"},
      expression_attribute_values: {":Sort" => "USER~v0", ":Partition" => "@"},
    )
    puts JSON.pretty_generate(items: res.items)
  end

  desc "Get user"
  task :get, [:name] do |t,args|
    name = args[:name]

    # Get user versions
    resp = YMD.query(
      key_condition_expression:    "#P = :Partition AND begins_with(#S, :Sort)",
      expression_attribute_names:  {"#P" => "Partition", "#S" => "Sort"},
      expression_attribute_values: {":Partition" => "@#{name}", ":Sort" => "USER~"},
    )
    puts JSON.pretty_generate(items: resp.items)
  end

  desc "Create new user"
  task :new, [:name] do |t,args|
    name = args[:name]

    # Create new user
    item = {
      Partition: "@#{name}",
      Sort:      "USER~v0",
      CreatedUTC: Time.now.utc.iso8601,
    }
    YMD.put_item(item: item)
  end

  desc "Get feed for user"
  task :feed, [:name, :time] do |t,args|
    name, time = args.values_at(:name, :time)
    time     ||= Time.now.utc.iso8601

    # Get feed for @name
    resp = YMD.query(
      index_name:                  "PartitionTime",
      key_condition_expression:    "#P = :Partition AND #T >= :Time",
      expression_attribute_names:  {"#P" => "Partition", "#T" => "Time"},
      expression_attribute_values: {":Partition" => "@#{name}/*", ":Time" => time},
    )
    puts JSON.pretty_generate(items: resp.items)
  end
end
