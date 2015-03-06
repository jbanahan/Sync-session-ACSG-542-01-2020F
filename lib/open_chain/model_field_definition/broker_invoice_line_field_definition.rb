module OpenChain; module ModelFieldDefinition; module BrokerInvoiceLineFieldDefinition
  def add_broker_invoice_line_fields
    add_fields CoreModule::BROKER_INVOICE_LINE, [
      [1,:bi_line_charge_code,:charge_code,"Charge Code",{:data_type=>:string}],
      [2,:bi_line_charge_description,:charge_description,"Description",{:data_type=>:string}],
      [3,:bi_line_charge_amount,:charge_amount,"Amount",{:data_type=>:decimal}],
      [4,:bi_line_vendor_name,:vendor_name,"Vendor",{:data_type=>:string}],
      [5,:bi_line_vendor_reference,:vendor_reference,"Vendor Reference",{:data_type=>:string}],
      [6,:bi_line_charge_type,:charge_type,"Charge Type",{:data_type=>:string,:can_view_lambda=>lambda {|u| u.company.broker?}}],
      [7,:bi_line_hst_percent,:hst_percent,"HST Percent",{:data_type=>:decimal}]
    ]
  end
end; end; end
