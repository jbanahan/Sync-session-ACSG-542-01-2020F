module OpenChain; module ModelFieldDefinition; module VfiInvoiceFieldDefinition
  def add_vfi_invoice_fields
    add_fields CoreModule::VFI_INVOICE, [
      [1, :vi_invoice_date, :invoice_date, "Invoice Date", {
        :data_type=>:date,
        :import_lambda=>lambda {|obj, data| "VFI Invoice Date ignored. (read only)"}}],
      [2, :vi_invoice_number, :invoice_number, "Invoice Number", {
        :data_type=>:string,
        :import_lambda=>lambda {|obj, data| "VFI Invoice Number ignored. (read only)"}}],
      [3, :vi_invoice_currency, :currency, "Currency", {
        :data_type=>:string,
        :import_lambda=>lambda {|obj, data| "VFI Invoice Currency ignored. (read only)"}}],
      [4, :vi_invoice_total, :invoice_total, "Total Charges", {
        :data_type=>:decimal,
        :currency=>:other,
        :import_lambda=>lambda {|obj, data| "Invoice Total ignored. (read only)"},
        :export_lambda=> lambda {|inv| inv.vfi_invoice_lines.inject(0) { |acc, nxt| acc + nxt.charge_amount }},
        :qualified_field_name=>"(select sum(vil.charge_amount) from vfi_invoices vi inner join vfi_invoice_lines vil on vi.id = vil.vfi_invoice_id where vil.vfi_invoice_id = vfi_invoices.id)"
      }]
    ]
    add_fields CoreModule::VFI_INVOICE, make_customer_arrays(100, "vi", "vfi_invoices")
  end
end; end; end
