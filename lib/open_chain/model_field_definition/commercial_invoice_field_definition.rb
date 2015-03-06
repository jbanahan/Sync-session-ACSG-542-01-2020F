module OpenChain; module ModelFieldDefinition; module CommercialInvoiceFieldDefinition
  def add_commercial_invoice_fields
    add_fields CoreModule::COMMERCIAL_INVOICE, [
      [1,:ci_invoice_number,:invoice_number,"Invoice Number",{:data_type=>:string}],
      [2,:ci_vendor_name,:vendor_name,"Vendor Name",{:data_type=>:string}],
      [3,:ci_currency,:currency,"Currency",{:data_type=>:string}],
      [4,:ci_invoice_value_foreign,:invoice_value_foreign,"Invoice Value (Foreign)",{:data_type=>:decimal,:currency=>:other}],
      [5,:ci_invoice_value,:invoice_value,"Invoice Value",{:data_type=>:decimal,:currency=>:usd}],
      [6,:ci_country_origin_code,:country_origin_code,"Country Origin Code",{:data_type=>:string}],
      [7,:ci_gross_weight,:gross_weight,"Gross Weight",{:data_type=>:integer}],
      [8,:ci_total_charges,:total_charges,"Charges",{:data_type=>:decimal,:currency=>:usd}],
      [9,:ci_invoice_date,:invoice_date,"Invoice Date",{:data_type=>:date}],
      [10,:ci_mfid,:mfid,"MID",{:data_type=>:string}],
      [11,:ci_exchange_rate,:exchange_rate,"Exchange Rate",{:data_type=>:decimal}],
      [12,:ci_total_quantity, :total_quantity, "Quantity",{:data_type=>:decimal}],
      [13,:ci_total_quantity_uom, :total_quantity_uom, "Quantity UOM",{:data_type=>:string}],
      [14,:ci_docs_received_date,:docs_received_date,'Docs Received Date',{data_type: :date}],
      [15,:ci_docs_ok_date,:docs_ok_date,'Docs OK Date',{data_type: :date}],
      [16,:ci_issue_codes,:issue_codes,'Issue Tracking Codes',{data_type: :string}],
      [17,:ci_rater_comments,:rater_comments,'Rater Comments',{data_type: :text}],
      [18,:ci_destination_code,:destination_code,'Destination Code',{data_type: :string}],
      [19,:ci_updated_at,:updated_at,"Last Updated",{data_type: :datetime,read_only: true}]
    ]
    add_fields CoreModule::COMMERCIAL_INVOICE, make_importer_arrays(100,'ci','commercial_invoices')
  end
end; end; end
