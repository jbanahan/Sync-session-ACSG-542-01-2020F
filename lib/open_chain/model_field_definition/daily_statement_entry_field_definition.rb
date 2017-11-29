module OpenChain; module ModelFieldDefinition; module DailyStatementEntryFieldDefinition

  def add_daily_statement_entry_fields
    add_fields CoreModule::CUSTOMS_DAILY_STATEMENT_ENTRY, [
      [1, :dse_broker_reference, :broker_reference, "Broker Reference", {data_type: :string}],
      [2, :dse_port_code, :port_code, "Port Code", {data_type: :string}],
      [3, :dse_port_name, :port_name, "Port Name", {data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.port.try(:name).to_s },
        :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_d_code = daily_statement_entries.port_code)"
      }],
      [4, :dse_total_amount, :total_amount, "Total Amount", {data_type: :decimal, currency: :usd}],
      [5, :dse_preliminary_total_amount, :preliminary_total_amount, "Preliminary Total Amount", {data_type: :decimal, currency: :usd}],
      [6, :dse_duty_amount, :duty_amount, "Duty Amount", {data_type: :decimal, currency: :usd}],
      [7, :dse_preliminary_duty_amount, :preliminary_duty_amount, "Preliminary Duty Amount", {data_type: :decimal, currency: :usd}],
      [8, :dse_tax_amount, :tax_amount, "Tax Amount", {data_type: :decimal, currency: :usd}],
      [9, :dse_preliminary_tax_amount, :preliminary_tax_amount, "Preliminary Tax Amount", {data_type: :decimal, currency: :usd}],
      [10, :dse_cvd_amount, :cvd_amount, "CVD Amount", {data_type: :decimal, currency: :usd}],
      [11, :dse_preliminary_cvd_amount, :preliminary_cvd_amount, "Preliminary CVD Amount", {data_type: :decimal, currency: :usd}],
      [12, :dse_add_amount, :add_amount, "ADD Amount", {data_type: :decimal, currency: :usd}],
      [13, :dse_preliminary_add_amount, :preliminary_add_amount, "Preliminary ADD Amount", {data_type: :decimal, currency: :usd}],
      [14, :dse_interest_amount, :interest_amount, "Interest Amount", {data_type: :decimal, currency: :usd}],
      [15, :dse_preliminary_interest_amount, :preliminary_interest_amount, "Preliminary Interest Amount", {data_type: :decimal, currency: :usd}],
      [16, :dse_fee_amount, :fee_amount, "Fee Amount", {data_type: :decimal, currency: :usd}],
      [17, :dse_preliminary_fee_amount, :preliminary_fee_amount, "Preliminary Fee Amount", {data_type: :decimal, currency: :usd}],
      [18, :dse_entry_number, :entry_number, "Entry Number", {data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.entry.try(:entry_number).to_s },
        :qualified_field_name => "(SELECT entry_number FROM entries WHERE entries.id = daily_statement_entries.entry_id)"
      }],
      [19, :dse_entry_type, :entry_type, "Entry Type", {data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.entry.try(:entry_type).to_s },
        :qualified_field_name => "(SELECT entry_type FROM entries WHERE entries.id = daily_statement_entries.entry_id)"
      }],
      [20, :dse_customer_number, :customer_number, "Customer Number", {data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.entry.try(:customer_number).to_s },
        :qualified_field_name => "(SELECT customer_number FROM entries WHERE entries.id = daily_statement_entries.entry_id)"
      }],
      [21, :dse_importer_name, :importer_name, "Customer Name", {data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.entry.try(:importer).try(:name).to_s },
        :qualified_field_name => "(SELECT i.name FROM entries INNER JOIN companies i ON entries.importer_id = i.id WHERE entries.id = daily_statement_entries.entry_id)"
      }],
      [22, :dse_billed_amount, :billed_amount, "Billed Amount", {data_type: :decimal, currency: :usd}]
    ]
  end

end; end; end