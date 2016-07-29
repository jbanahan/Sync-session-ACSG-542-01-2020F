module OpenChain; module ModelFieldDefinition; module VfiInvoiceLineFieldDefinition
  def add_vfi_invoice_line_fields
    add_fields CoreModule::VFI_INVOICE_LINE, [
      [1,:vi_line_number,:line_number,"Line Number",{
          :data_type=>:integer,
          :import_lambda=>lambda {|obj,data| "VFI Invoice Line Number ignored. (read only)"}}],
      [2,:vi_line_charge_description,:charge_description,"Description",{
        :data_type=>:string,
        :import_lambda=>lambda {|obj,data| "VFI Invoice Line Charge Description ignored. (read only)"}}],
      [3,:vi_line_charge_amount,:charge_amount,"Charges",{
        :data_type=>:decimal,
        :import_lambda=>lambda {|obj,data| "VFI Invoice Line Charge Amount ignored. (read only)"}}],
      [4,:vi_line_charge_code,:charge_code,"Charge Code",{
        :data_type=>:string,
        :import_lambda=>lambda {|obj,data| "VFI Invoice Line Charge Code ignored. (read only)"},
        :can_view_lambda=>lambda {|u| u.company.broker?}}],
      [5,:vi_line_quantity,:quantity,"Quantity",{
        :data_type=>:decimal,
        :import_lambda=>lambda {|obj,data| "VFI Invoice Line Quantity ignored. (read only)"}}],
      [6,:vi_line_unit,:unit,"Unit",{
        :data_type=>:string,
        :import_lambda=>lambda {|obj,data| "VFI Invoice Line Unit ignored. (read only)"}}],
      [7,:vi_line_unit_price,:unit_price,"Unit Price",{
        :data_type=>:decimal,
        :import_lambda=>lambda {|obj,data| "VFI Invoice Unit Price ignored. (read only)"}}]
    ]
  end
end; end; end
