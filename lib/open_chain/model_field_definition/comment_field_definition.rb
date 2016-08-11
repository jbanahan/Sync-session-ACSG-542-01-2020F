module OpenChain; module ModelFieldDefinition; module CommentFieldDefinition
  def add_comment_fields
    add_fields CoreModule::COMMENT, [
      [1, :cmt_subject, :subject, "Subject", {data_type: :string}],
      [2, :cmt_body, :body, "Body", {data_type: :string}],
      [3, :cmt_created_at, :created_at, "Created At", {data_type: :datetime, read_only: true}],
      [4, :cmt_unique_identifier, :unique_identifier, "Unique Identifier", {data_type: :string, read_only: true,
          export_lambda: lambda {|cmt| "#{cmt.id}-#{cmt.subject}"},
          qualified_field_name: "CONCAT(comments.id, '-', ifnull(comments.subject, ''))"}]
    ]

    add_fields CoreModule::COMMENT, make_user_fields(100, :cmt_user, "Created By", CoreModule::COMMENT, :user)
  end
end; end; end;
