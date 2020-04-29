module OpenChain; module ModelFieldDefinition; module SummaryStatementFieldDefinition
  def add_summary_statement_fields
    add_fields CoreModule::SUMMARY_STATEMENT, [
      [1, :sum_statement_num, :statement_number, "Statement Number", {:data_type=>:string}]
    ]
    add_fields CoreModule::SUMMARY_STATEMENT, make_customer_arrays(100, "sum", "summary_statements")
  end
end; end; end
