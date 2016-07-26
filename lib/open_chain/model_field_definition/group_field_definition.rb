module OpenChain; module ModelFieldDefinition; module GroupFieldDefinition
  def add_group_fields
    add_fields CoreModule::GROUP, [
      [1, :grp_name, :name, "Name", {data_type: :string}],
      [2, :grp_system_code, :system_code, "System Code", {data_type: :string, read_only: true}],
      [3, :grp_description, :description, "Description", {data_type: :string}]
    ]
  end
end; end; end;