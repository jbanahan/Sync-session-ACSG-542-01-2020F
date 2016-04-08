module OpenChain; module ModelFieldDefinition; module EntryCommentFieldDefinition
  def add_entry_comment_fields
    add_fields CoreModule::ENTRY_COMMENT, [
      [1, :ent_com_body, :body, "Body", {data_type: :string}],
      [2, :ent_com_created_at, :generated_at, "Created At", {data_type: :datetime}],
      [3, :ent_com_username, :username, "Created By", {data_type: :string}],
      [4, :ent_com_public, :public_comment, "Public?", {data_type: :boolean, can_view_lambda: lambda {|u| u.company.broker? }}]
    ]
  end
end; end; end