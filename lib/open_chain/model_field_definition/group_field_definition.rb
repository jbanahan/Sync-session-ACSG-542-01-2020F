module OpenChain; module ModelFieldDefinition; module GroupFieldDefinition
  def add_group_fields
    add_fields CoreModule::GROUP, [
      [1, :grp_name, :name, "Name", {data_type: :string}],
      [2, :grp_system_code, :system_code, "System Code", {data_type: :string, read_only: true}],
      [3, :grp_description, :description, "Description", {data_type: :string}],
      [4, :grp_unique_identifier, :unique_identifier, "Unique Identifier", {data_type: :string, read_only: true,
          export_lambda: lambda {|grp| "#{grp.id}-#{grp.name}"},
          qualified_field_name: "CONCAT(groups.id, '-', ifnull(groups.name, ''))"}]
    ]
  end
end; end; end;
