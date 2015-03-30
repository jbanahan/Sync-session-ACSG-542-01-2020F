module OpenChain; module ModelFieldGenerator; module AttachmentGenerator
  def make_attachment_arrays(rank_start,uid_prefix,core_module,can_view_lambda_map={})
    rank = rank_start
    r = []
    r << [rank,"#{uid_prefix}_attachment_types".to_sym,:attachment_types,"Attachment Types",{
      data_type: :string,
      export_lambda: lambda {|obj| obj.attachment_types.join("\n ") },
      qualified_field_name: "(SELECT GROUP_CONCAT(DISTINCT a_types.attachment_type ORDER BY a_types.attachment_type SEPARATOR '\n ')
        FROM attachments a_types
        WHERE a_types.attachable_id = #{core_module.table_name}.id AND a_types.attachable_type = '#{core_module.class_name}' AND LENGTH(RTRIM(IFNULL(a_types.attachment_type, ''))) > 0)",
      can_view_lambda: can_view_lambda_map["#{uid_prefix}_attachment_types".to_sym],
      read_only: true
    }]
    rank += 1
    r << [rank,"#{uid_prefix}_attachment_count".to_sym,:attachment_count,"Attachment Count",{
      data_type: :integer,
      read_only: true,
      qualified_field_name: "(SELECT COUNT(*) FROM attachments where attachments.attachable_id = #{core_module.table_name}.id AND attachments.attachable_type = '#{core_module.class_name}')",
      export_lambda: lambda {|obj| obj.attachments.size}
    }]
    r
  end
end; end; end
