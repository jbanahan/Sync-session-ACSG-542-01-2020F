module OpenChain; module ModelFieldDefinition; module AttachmentFieldDefinition
  def add_attachment_fields
    add_fields CoreModule::ATTACHMENT, [
      [1, :att_file_name, :attached_file_name, "File Name", {data_type: :string, read_only: true}],
      [2, :att_attachment_type, :attachment_type, "Attachment Type", {data_type: :string, read_only: true}],
      [3, :att_file_size, :attached_file_size, "File Size", {data_type: :integer, read_only: true}],
      [4, :att_content_type, :attached_content_type, "Content Type", {data_type: :string, read_only: true}],
      [5, :att_source_system_timestamp, :source_system_timestamp, "Created At", {data_type: :datetime, read_only: true}],
      [6, :att_updated_at, :attached_updated_at, "Uploaded At", {data_type: :datetime, read_only: true}],
      [7, :att_revision, :alliance_revision, "Revision", {data_type: :integer, read_only: true}],
      [8, :att_suffix, :alliance_suffix, "Suffix", {data_type: :string, read_only: true}],
      [9, :att_private, :is_private, "Private?", {data_type: :boolean, read_only: true, can_view_lambda: lambda {|u| u.company.master? }}],
      [10, :att_unique_identifier, :unique_identifier, "Unique Identifier", {data_type: :string, read_only: true,
          export_lambda: lambda {|att| "#{att.id}-#{att.attached_file_name}"},
          qualified_field_name: "CONCAT(attachments.id, '-', ifnull(attachments.attached_file_name, ''))"}]
    ]
    add_fields CoreModule::ATTACHMENT, make_user_fields(100, :att_uploaded_by, "Uploaded By", CoreModule::ATTACHMENT, :uploaded_by)
  end
end; end; end