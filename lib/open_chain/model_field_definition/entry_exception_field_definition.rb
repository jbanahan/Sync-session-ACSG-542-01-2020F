module OpenChain; module ModelFieldDefinition; module EntryExceptionFieldDefinition
  def add_entry_exception_fields
    add_fields CoreModule::ENTRY_EXCEPTION, [
      [1, :ent_except_code, :code, "Exception Code", {data_type: :string}],
      [2, :ent_except_resolved, :resolved, "Resolved?", {
        data_type: :boolean,
        read_only: true,
        export_lambda: ->(ent_ex) { ent_ex.resolved_date.present? },
        qualified_field_name: "(entry_exceptions.resolved_date IS NOT NULL)"
      }],
      [3, :ent_except_comments, :comments, "Comments", {data_type: :text}]
    ]
  end
end; end; end