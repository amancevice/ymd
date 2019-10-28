namespace :subs do
  desc "List subscriptions for @name"
  task :list, [:name] do |t,args|
    name = args[:name]

    # Get subscriptions
    resp = YMD.query(
      key_condition_expression:    "#P = :Partition AND begins_with(#S, :Sort)",
      expression_attribute_names:  {"#P" => "Partition", "#S" => "Sort"},
      expression_attribute_values: {":Partition" => "@#{name}", ":Sort" => "SUB~"},
    )
    puts JSON.pretty_generate(items: resp.items)
  end

  desc "Get subscription"
  task :get, [:name,:user,:ical] do |t,args|
    name, user, ical = args.values_at(:name, :user, :ical)

    resp = YMD.query(
      key_condition_expression:    "#P = :Partition AND #S = :Sort",
      expression_attribute_names:  {"#P" => "Partition", "#S" => "Sort"},
      expression_attribute_values: {":Partition" => "@#{name}", ":Sort" => "SUB~@#{user}/##{ical}"},
    )
    puts JSON.pretty_generate(items: resp.items)
  end

  desc "Subscribe @name to @user/#ical"
  task :new, [:name,:user,:ical] do |t,args|
    name, user, ical = args.values_at(:name, :user, :ical)

    # Create new subscription
    item = {Partition: "@#{name}", Sort: "SUB~@#{user}/##{ical}"}
    YMD.put_item(item: item)

    # Get events to add to feed
    resp = YMD.query(
      index_name:                  "SortPartition",
      key_condition_expression:    "#S = :Sort AND begins_with(#P, :Partition)",
      expression_attribute_names:  {"#S" => "Sort", "#P" => "Partition"},
      expression_attribute_values: {":Sort" => "EVENT~v0", ":Partition" => "@#{user}/##{ical}"},
    )

    # Add events to feed
    feed = "@#{name}/*"
    resp.items.each do |item|
      item.update("Partition" => feed, "Sort" => item["Partition"])
      YMD.put_item(item: item)
    end
  end
end
