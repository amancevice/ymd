require "time"

namespace :users do
  desc "List @users"
  task :list do
    res = YMD.query(
      index_name:                  "SortPartition",
      key_condition_expression:    "#S = :Sort AND begins_with(#P, :Partition)",
      expression_attribute_names:  {"#S" => "Sort", "#P" => "Partition"},
      expression_attribute_values: {":Sort" => "USER~v0", ":Partition" => "@"},
    )
    puts JSON.pretty_generate(items: res.items)
  end

  desc "Get @user"
  task :get, [:name] do |t,args|
    res = YMD.query(
      index_name:                  "SortPartition",
      key_condition_expression:    "#S = :Sort AND #P = :Partition",
      expression_attribute_names:  {"#S" => "Sort", "#P" => "Partition"},
      expression_attribute_values: {":Sort" => "USER~v0", ":Partition" => args[:name]},
    )
    puts JSON.pretty_generate(res.items.first)
  end

  desc "Create @user"
  task :new, [:name] do |t,args|
    item = {
      Partition: args[:name],
      Sort:      "USER~v0",
      CreatedUTC: Time.now.utc.iso8601,
    }
    YMD.put_item(item: item)
  end

  desc "Get @user's feed"
  task :feed, [:name, :time] do |t,args|
    hash = "#{args[:name]}/*"
    sort = args[:time] || Time.now.utc.iso8601
    resp = YMD.query(
      index_name:                  "PartitionTime",
      key_condition_expression:    "#P = :Partition AND #T >= :Time",
      expression_attribute_names:  {"#P" => "Partition", "#T" => "Time"},
      expression_attribute_values: {":Partition" => hash, ":Time" => sort},
    )
    puts JSON.pretty_generate(items: resp.items)
  end

  desc "Subscribe to feed"
  task :sub, [:name,:user,:ical] do |t,args|
    name = args[:name]
    user = args[:user]
    ical = args[:ical]
    link = "#{user}/##{ical}"
    item = {Partition: name, Sort: "SUB~#{link}"}
    YMD.put_item(item: item)

    resp = YMD.query(
      index_name:                  "SortPartition",
      key_condition_expression:    "#S = :Sort AND begins_with(#P, :Partition)",
      expression_attribute_names:  {"#S" => "Sort", "#P" => "Partition"},
      expression_attribute_values: {":Sort" => "EVENT~v0", ":Partition" => link},
    )
    resp.items.each do |item|
      item.update("Partition" => "#{user}/*", "Sort" => item["Partition"])
      YMD.put_item(item: item)
    end
  end
end
