module OpenChain; module ModelFieldDefinition; module DailyStatementEntryFeeFieldDefinition

  def add_daily_statement_entry_fee_fields
    add_fields CoreModule::CUSTOMS_DAILY_STATEMENT_ENTRY_FEE, [
      [1, :dsef_code, :code, "Code", {data_type: :string}],
      [2, :dsef_description, :description, "Description", {data_type: :string}],
      [3, :dsef_amount, :amount, "Amount", {data_type: :decimal, currency: :usd}],
      [4, :dsef_preliminary_amount, :preliminary_amount, "Preliminary Amount", {data_type: :decimal, currency: :usd}]
    ]
  end

end; end; end