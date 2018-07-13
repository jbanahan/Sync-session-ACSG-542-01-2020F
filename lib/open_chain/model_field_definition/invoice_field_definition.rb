module OpenChain; module ModelFieldDefinition; module InvoiceFieldDefinition
  def add_invoice_fields
    add_fields CoreModule::INVOICE, [
        [1,:inv_country_origin_name, :country_origin_id, "Origin Country", {
            export_lambda: lambda { |obj|
              c = obj.country_origin.name || obj.country_origin.id
            },
            :qualified_field_name => "(SELECT name from countries where countries.id = invoices.country_origin_id)",
            :data_type => :string
        }],
        [2,:inv_currency, :currency, "Currency", {data_type: :string}],
        [3,:inv_cust_ref_num, :customer_reference_number, "Customer Reference Number", {data_type: :string}],
        [4,:inv_desc_of_goods, :description_of_goods, "Description of Goods", {data_type: :text}],
        [5,:inv_exchange_rate, :exchange_rate, "Exchange Rate", {data_type: :decimal}],
        [6,:inv_factory_name, :factory_id, "Factory Name", {
            export_lambda: lambda { |obj|
              f = obj.factory.name || obj.factory.id
            },
            :qualified_field_name => "(SELECT name from companies where companies.id = invoices.factory_id)",
            :data_type => :string
        }],
        [7,:inv_gross_weight, :gross_weight, "Gross Weight", {data_type: :decimal}],
        [8,:inv_gross_weight_uom, :gross_weight_uom, "Gross Weight UOM", {data_type: :string}],
        [9,:inv_importer_name, :importer_id, "Importer Name", {
            export_lambda: lambda { |obj|
              i = obj.importer.name || obj.importer.id
            },
            :qualified_field_name => "(SELECT name from companies where companies.id = invoices.importer_id)",
            :data_type => :string
        }],
        [10,:inv_inv_date, :invoice_date, "Invoice Date", {datatype: :date}],
        [11,:inv_inv_num, :invoice_number, "Invoice Number", {datatype: :string}],
        [12,:inv_inv_tot_domestic, :invoice_total_domestic, "Invoice Total - Domestic", {datatype: :decimal}],
        [13,:inv_inv_tot_foreign, :invoice_total_foreign, "Invoice Total - Foreign", {datatype: :decimal}],
        [14,:inv_net_invoice_total, :net_invoice_total, "Net Invoice Total", {datatype: :decimal}],
        [15,:inv_net_weight, :net_weight, "Net Weight", {datatype: :decimal}],
        [16,:inv_net_weight_uom, :net_weight_uom, "Net Weight UOM", {datatype: :string}],
        [17,:inv_ship_mode, :ship_mode, "Ship Mode", {datatype: :string}],
        [18,:inv_terms_of_payment, :terms_of_payment, "Payment Terms", {datatype: :string}],
        [19,:inv_terms_of_sale, :terms_of_sale, "Sale Terms", {datatype: :string}],
        [20,:inv_total_charges, :total_charges, "Total Charges", {datatype: :decimal}],
        [21,:inv_total_discounts, :total_discounts, "Total Discounts", {datatype: :decimal}],
        [22,:inv_volume, :volume, "Volume", {datatype: :decimal}],
        [23,:inv_volume_uom, :volume_uom, "Volume UOM", {datatype: :string}],
        [24,:inv_vendor_name, :vendor_id, "Vendor Name", {
            export_lambda: lambda { |obj|
              i = obj.vendor.name || obj.vendor.id
            },
            :qualified_field_name => "(SELECT name from companies where companies.id = invoices.vendor_id)",
            :data_type => :string
        }],
    ]
  end
end; end; end