module OpenChain; module ModelFieldDefinition; module InvoiceFieldDefinition
  def add_invoice_fields
    add_fields CoreModule::INVOICE, [
        [1,:inv_currency, :currency, "Currency", {data_type: :string}],
        [2,:inv_cust_ref_num, :customer_reference_number, "Customer Reference Number", {data_type: :string}],
        [3,:inv_desc_of_goods, :description_of_goods, "Description of Goods", {data_type: :text}],
        [4,:inv_exchange_rate, :exchange_rate, "Exchange Rate", {data_type: :decimal}],
        [5,:inv_gross_weight, :gross_weight, "Total Gross Weight", {data_type: :decimal}],
        [6,:inv_gross_weight_uom, :gross_weight_uom, "Total Gross Weight UOM", {data_type: :string}],
        [7,:inv_inv_date, :invoice_date, "Invoice Date", {datatype: :date}],
        [8,:inv_inv_num, :invoice_number, "Invoice Number", {datatype: :string}],
        [9,:inv_inv_tot_domestic, :invoice_total_domestic, "Invoice Total - Domestic", {datatype: :decimal}],
        [10,:inv_inv_tot_foreign, :invoice_total_foreign, "Invoice Total - Foreign", {datatype: :decimal}],
        [11,:inv_net_invoice_total, :net_invoice_total, "Net Invoice Total", {datatype: :decimal}],
        [12,:inv_net_weight, :net_weight, "Net Weight", {datatype: :decimal}],
        [13,:inv_net_weight_uom, :net_weight_uom, "Net Weight UOM", {datatype: :string}],
        [14,:inv_ship_mode, :ship_mode, "Ship Mode", {datatype: :string}],
        [15,:inv_terms_of_payment, :terms_of_payment, "Payment Terms", {datatype: :string}],
        [16,:inv_terms_of_sale, :terms_of_sale, "Sale Terms", {datatype: :string}],
        [17,:inv_total_charges, :total_charges, "Total Charges", {datatype: :decimal}],
        [18,:inv_total_discounts, :total_discounts, "Total Discounts", {datatype: :decimal}],
        [19,:inv_volume, :volume, "Total Volume", {datatype: :decimal}],
        [20,:inv_volume_uom, :volume_uom, "Total Volume UOM", {datatype: :string}]
    ]
    add_fields CoreModule::INVOICE, make_importer_arrays(1000,"inv","invoices")
    add_fields CoreModule::INVOICE, make_vendor_arrays(2000,"inv","invoices")
    add_fields CoreModule::INVOICE, make_factory_arrays(3000,'inv','invoices')
    add_fields CoreModule::INVOICE, make_country_arrays(4000,"inv_origin","invoices", "country_origin", association_title: "Origin", country_selector: DefaultCountrySelector)
    
  end
end; end; end