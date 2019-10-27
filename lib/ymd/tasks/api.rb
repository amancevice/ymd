namespace :api do
  desc "Get @user's feed"
  task :feed, [:user, :time] do |t,args|
    hash = "#{args[:user]}/*"
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
  task :subscribe, [:user,:other,:cal] do |t,args|
    ical = "#{args[:other]}/##{args[:cal]}"
    user = args[:user]
    item = {Partition: user, Sort: "SUB~#{ical}"}
    YMD.put_item(item: item)

    resp = YMD.query(
      index_name:                  "SortPartition",
      key_condition_expression:    "#S = :Sort AND begins_with(#P, :Partition)",
      expression_attribute_names:  {"#S" => "Sort", "#P" => "Partition"},
      expression_attribute_values: {":Sort" => "EVENT~v0", ":Partition" => ical},
    )
    resp.items.each do |item|
      item.update("Partition" => "#{user}/*", "Sort" => item["Partition"])
      YMD.put_item(item: item)
    end
  end
end
