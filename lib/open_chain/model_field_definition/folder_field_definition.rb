module OpenChain; module ModelFieldDefinition; module FolderFieldDefinition
  def add_folder_fields
    add_fields CoreModule::FOLDER, [
      [1, :fld_name, :name, "Name", {data_type: :string}],
      [2, :fld_created_at, :created_at, "Created At", {data_type: :datetime}]
    ]

    add_fields CoreModule::FOLDER, make_user_fields(100, :fld_created_by, "Created By", CoreModule::FOLDER, :created_by)
  end
end; end; end;