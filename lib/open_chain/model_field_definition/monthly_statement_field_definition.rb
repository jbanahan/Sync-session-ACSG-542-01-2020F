module OpenChain; module ModelFieldDefinition; module MonthlyStatementFieldDefinition

  def add_monthly_statement_fields
    add_fields CoreModule::CUSTOMS_MONTHLY_STATEMENT, [
      [1, :cms_statement_number, :statement_number, "Statement Number", {data_type: :string}],
      [2, :cms_status, :status, "Status", {data_type: :string}],
      [3, :cms_received_date, :received_date, "Received Date", {data_type: :date}],
      [4, :cms_final_received_date, :final_received_date, "Final Received Date", {data_type: :date}],
      [5, :cms_due_date, :due_date, "Due Date", {data_type: :date}],
      [6, :cms_paid_date, :paid_date, "Paid Date", {data_type: :date}],
      [7, :cms_pay_type, :pay_type, "Pay Type", {data_type: :string}],
      [8, :cms_pay_type_description, :pay_type_description, "Pay Type Description", {data_type: :string,
        history_ignore: true, 
        read_only: true,
        export_lambda: lambda {|s| s.pay_type_description },
        qualified_field_name: "(CASE pay_type WHEN '1' THEN 'Direct Payment' WHEN '2' THEN 'Broker Daily Statement' WHEN '3' THEN 'Importer Daily Statement' WHEN '6' THEN 'Broker Daily Statement' WHEN '7' THEN 'Importer Daily Statement' ELSE '' END)"
      }],
      [9, :cms_port_code, :port_code, "Port Code", {data_type: :string}],
      [10, :cms_total_amount, :total_amount, "Total Amount", {data_type: :decimal, currency: :usd}],
      [11, :cms_preliminary_total_amount, :preliminary_total_amount, "Preliminary Total Amount", {data_type: :decimal, currency: :usd}],
      [12, :cms_duty_amount, :duty_amount, "Duty Amount", {data_type: :decimal, currency: :usd}],
      [13, :cms_preliminary_duty_amount, :preliminary_duty_amount, "Preliminary Duty Amount", {data_type: :decimal, currency: :usd}],
      [14, :cms_tax_amount, :tax_amount, "Tax Amount", {data_type: :decimal, currency: :usd}],
      [15, :cms_preliminary_tax_amount, :preliminary_tax_amount, "Preliminary Tax Amount", {data_type: :decimal, currency: :usd}],
      [16, :cms_cvd_amount, :cvd_amount, "CVD Amount", {data_type: :decimal, currency: :usd}],
      [17, :cms_preliminary_cvd_amount, :preliminary_cvd_amount, "Preliminary CVD Amount", {data_type: :decimal, currency: :usd}],
      [18, :cms_add_amount, :add_amount, "ADD Amount", {data_type: :decimal, currency: :usd}],
      [19, :cms_preliminary_add_amount, :preliminary_add_amount, "Preliminary ADD Amount", {data_type: :decimal, currency: :usd}],
      [20, :cms_interest_amount, :interest_amount, "Interest Amount", {data_type: :decimal, currency: :usd}],
      [21, :cms_preliminary_interest_amount, :preliminary_interest_amount, "Preliminary Interest Amount", {data_type: :decimal, currency: :usd}],
      [22, :cms_fee_amount, :fee_amount, "Fee Amount", {data_type: :decimal, currency: :usd}],
      [23, :cms_preliminary_fee_amount, :preliminary_fee_amount, "Preliminary Fee Amount", {data_type: :decimal, currency: :usd}],
      [24, :cms_port_name, :port_name,"Port Name",{data_type: :string, read_only: true, history_ignore: true,
        :export_lambda => lambda {|s| s.port.try(:name).to_s },
        :qualified_field_name => "(SELECT name FROM ports WHERE ports.schedule_d_code = monthly_statements.port_code)"
      }],
      [25, :cms_importer_name, :importer_name, "Customer Name", {data_type: :string, read_only: true, history_ignore: true,
        export_lambda: lambda {|s| s.importer.try(:name).to_s },
        qualified_field_name: "(SELECT name FROM companies importer_name WHERE importer_name.id = monthly_statements.importer_id)"
      }],
      [26, :cms_customer_number, :customer_number, "Customer Number", {data_type: :string}],
      [27, :cms_status_description, :status_description, "Status Description", {data_type: :string, 
        history_ignore: true, 
        read_only: true,
        export_lambda: lambda {|s| s.status_description },
        qualified_field_name: "(CASE pay_type WHEN 'P' THEN 'Preliminary' WHEN 'F' THEN 'Final' ELSE '' END)"
      }]
    ]
  end

end; end; end;