module OpenChain; module ModelFieldDefinition; module DailyStatementFieldDefinition

  def add_daily_statement_fields
    add_fields CoreModule::CUSTOMS_DAILY_STATEMENT, [
      [1, :cds_statement_number, :statement_number, "Statement Number", {data_type: :string}],
      [2, :cds_status, :status, "Status", {data_type: :string}],
      [3, :cds_received_date, :received_date, "Received Date", {data_type: :date}],
      [4, :cds_final_received_date, :final_received_date, "Final Received Date", {data_type: :date}],
      [5, :cds_due_date, :due_date, "Due Date", {data_type: :date}],
      [6, :cds_paid_date, :paid_date, "Paid Date", {data_type: :date}],
      [7, :cds_payment_accepted_date, :payment_accepted_date, "Payment Accepted Date", {data_type: :date}],
      [8, :cds_pay_type, :pay_type, "Pay Type", {data_type: :string}],
      [9, :cds_pay_type_description, :pay_type_description, "Pay Type Description", {data_type: :string,
        history_ignore: true, 
        read_only: true,
        export_lambda: lambda {|s| s.pay_type_description },
        qualified_field_name: "(CASE pay_type WHEN '1' THEN 'Direct Payment' WHEN '2' THEN 'Broker Daily Statement' WHEN '3' THEN 'Importer Daily Statement' WHEN '6' THEN 'Broker Daily Statement' WHEN '7' THEN 'Importer Daily Statement' ELSE '' END)"
      }],
      [10, :cds_port_code, :port_code, "Port Code", {data_type: :string}],
      [11, :cds_total_amount, :total_amount, "Total Amount", {data_type: :decimal, currency: :usd}],
      [12, :cds_preliminary_total_amount, :preliminary_total_amount, "Preliminary Total Amount", {data_type: :decimal, currency: :usd}],
      [13, :cds_duty_amount, :duty_amount, "Duty Amount", {data_type: :decimal, currency: :usd}],
      [14, :cds_preliminary_duty_amount, :preliminary_duty_amount, "Preliminary Duty Amount", {data_type: :decimal, currency: :usd}],
      [15, :cds_tax_amount, :tax_amount, "Tax Amount", {data_type: :decimal, currency: :usd}],
      [16, :cds_preliminary_tax_amount, :preliminary_tax_amount, "Preliminary Tax Amount", {data_type: :decimal, currency: :usd}],
      [18, :cds_cvd_amount, :cvd_amount, "CVD Amount", {data_type: :decimal, currency: :usd}],
      [19, :cds_preliminary_cvd_amount, :preliminary_cvd_amount, "Preliminary CVD Amount", {data_type: :decimal, currency: :usd}],
      [20, :cds_add_amount, :add_amount, "ADD Amount", {data_type: :decimal, currency: :usd}],
      [21, :cds_preliminary_add_amount, :preliminary_add_amount, "Preliminary ADD Amount", {data_type: :decimal, currency: :usd}],
      [22, :cds_interest_amount, :interest_amount, "Interest Amount", {data_type: :decimal, currency: :usd}],
      [23, :cds_preliminary_interest_amount, :preliminary_interest_amount, "Preliminary Interest Amount", {data_type: :decimal, currency: :usd}],
      [24, :cds_fee_amount, :fee_amount, "Fee Amount", {data_type: :decimal, currency: :usd}],
      [24, :cds_preliminary_fee_amount, :preliminary_fee_amount, "Preliminary Fee Amount", {data_type: :decimal, currency: :usd}],
      [25, :cds_port_name, :port_name,"Port Name",{data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.port.try(:name).to_s },
        :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_d_code = daily_statements.port_code)"
      }],
      [27, :cds_importer_name, :importer_name, "Customer Name", {data_type: :string, read_only: true, history_ignore: true,
        export_lambda: lambda {|s| s.importer.try(:name).to_s },
        qualified_field_name: "(SELECT name FROM companies importer_name WHERE importer_name.id = daily_statements.importer_id)"
      }],
      [28, :cds_customer_number, :customer_number, "Customer Number", {data_type: :string}],
      [30, :cds_monthly_statement_number, :monthly_statement_number, "Monthly Statement Number", {data_type: :string}],
      [31, :cds_status_description, :status_description, "Status Description", {data_type: :string, 
        history_ignore: true, 
        read_only: true,
        export_lambda: lambda {|s| s.status_description },
        qualified_field_name: "(CASE pay_type WHEN 'P' THEN 'Preliminary' WHEN 'F' THEN 'Final' ELSE '' END)"
      }]
    ]
  end

end; end; end;