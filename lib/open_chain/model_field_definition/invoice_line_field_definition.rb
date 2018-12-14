module OpenChain; module ModelFieldDefinition; module InvoiceLineFieldDefinition
  def add_invoice_line_fields
    add_fields CoreModule::INVOICE_LINE, [
      [1,:invln_air_sea_disc, :air_sea_discount, "Discount - Air/Sea", {datatype: :decimal}],
      [2,:invln_department, :department, "Department", {datatype: :string}],
      [3,:invln_early_pay_disc, :early_pay_discount, "Discount - Early Payment", {datatype: :decimal}],
      [4,:invln_first_sale, :first_sale, "First Sale", {datatype: :decimal}],
      [5,:invln_fw, :fish_wildlife, "Fish and Wildlife", {datatype: :decimal}],
      [6,:invln_gross_weight, :gross_weight, "Gross Weight", {datatype: :integer}],
      [7,:invln_gross_weight_uom, :gross_weight_uom, "Gross Weight UOM", {datatype: :string}],
      [8,:invln_hts_number, :hts_number, "HTS Number", {datatype: :string, 
          export_lambda: lambda {|t| t.hts_number.blank? ? "" : t.hts_number.hts_format},
          search_value_preprocess_lambda: hts_search_value_preprocess_lambda
        }
      ],
      [9,:invln_ln_number, :line_number, "Line Number", {datatype: :integer}],
      [10,:invln_mid, :mid, "Mid", {datatype: :string}],
      [11,:invln_middle_charge, :middleman_charge, "Middleman Charge", {datatype: :decimal}],
      [12,:invln_net_weight, :net_weight, "Net Weight", {datatype: :decimal}],
      [13,:invln_net_weight_uom, :net_weight_uom, "Net Weight UOM", {datatype: :string}],
      [14,:invln_part_description, :part_description, "Part Description", {datatype: :string}],
      [15,:invln_part_number, :part_number, "Part Number", {datatype: :string}],
      [16,:invln_pieces, :pieces, "Pieces", {datatype: :decimal}],
      [17,:invln_po_number, :po_number, "PO Number", {datatype: :string}],
      [18,:invln_quantity, :quantity, "Quantity", {datatype: :decimal}],
      [19,:invln_quantity_uom, :quantity_uom, "Quantity UOM", {datatype: :string}],
      [20,:invln_trade_discount, :trade_discount, "Discount - Trade", {datatype: :decimal}],
      [21,:invln_unit_price, :unit_price, "Unit Price", {datatype: :decimal}],
      [22,:invln_value_domestic, :value_domestic, "Value - Domestic", {datatype: :decimal}],
      [23,:invln_value_foreign, :value_foreign, "Value - Foreign", {datatype: :decimal}],
      [24,:invln_volume, :volume, "Volume", {datatype: :decimal}],
      [25,:invln_volume_uom, :volume_uom, "Volume UOM", {datatype: :decimal}],
      [26,:invln_po_line_number, :po_line_number, "PO Line Number", {datatype: :string}],
      [27,:invln_master_bill_of_lading, :master_bill_of_lading, "Master Bill Of Lading", {datatype: :string}],
      [28,:invln_carrier_code, :carrier_code, "Carrier Code", {datatype: :string}],
      [29,:invln_cartons, :cartons, "Cartons", {datatype: :integer}],
      [30,:invln_customs_quantity, :customs_quantity, "Customs Quantity", {datatype: :decimal}],
      [31,:invln_customs_quantity_uom, :customs_quantity_uom, "Customs Quantity UOM", {datatype: :string}],
      [32,:invln_container_number, :container_number, "Container Number", {datatype: :string}],
      [33,:invln_related_parties, :related_parties, "Related Parties?", {datatype: :boolean}],
      [34,:invln_spi, :spi, "Special Program", {datatype: :string}],
      [35,:invln_spi2, :spi, "Secondary Special Program", {datatype: :string}]
    ]

    add_fields CoreModule::INVOICE_LINE, make_country_arrays(1000,"invln_origin","invoice_lines", "country_origin", association_title: "Origin", country_selector: DefaultCountrySelector)
    add_fields CoreModule::INVOICE_LINE, make_country_arrays(2000,"invln_export","invoice_lines", "country_export", association_title: "Export", country_selector: DefaultCountrySelector)
    
  end
end; end; end
