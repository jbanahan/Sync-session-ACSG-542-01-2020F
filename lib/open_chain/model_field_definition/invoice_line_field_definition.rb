module OpenChain; module ModelFieldDefinition; module InvoiceLineFieldDefinition
  def add_invoice_line_fields
    add_fields CoreModule::INVOICE_LINE, [
        [1,:invln_air_sea_disc, :air_sea_discount, "Discount - Air/Sea", {datatype: :decimal}],
        [2,:invln_country_export_name, :country_export_id, "Export Country", {
            export_lambda: lambda { |obj|
              c = obj.country_export.present? ? obj.country_export.name || obj.country_export.id : ''
            },
            qualified_field_name: "(SELECT name from countries where countries.id = invoice_lines.country_export_id)",
            datatype: :string
        }],
        [3,:invln_country_origin_name, :country_origin_id, "Origin Country", {
            export_lambda: lambda { |obj|
              c = obj.country_origin.present? ? obj.country_origin.name || obj.country_origin.id : ''
            },
            qualifed_field_name: "(SELECT name from countries where countries.id = invoice_lines.country_origin_id)",
            datatype: :string
        }],
        [4,:invln_department, :department, "Department", {datatype: :string}],
        [5,:invln_early_pay_disc, :early_pay_discount, "Discount - Early Payment", {datatype: :decimal}],
        [6,:invln_first_sale, :first_sale, "First Sale", {datatype: :decimal}],
        [7,:invln_fw, :fish_wildlife, "Fish and Wildlife", {datatype: :decimal}],
        [8,:invln_gross_weight, :gross_weight, "Gross Weight", {datatype: :integer}],
        [9,:invln_gross_weight_uom, :gross_weight_uom, "Gross Weight UOM", {datatype: :string}],
        [10,:invln_hts_number, :hts_number, "HTS Number", {datatype: :string}],
        [11,:invln_ln_number, :line_number, "Line Number", {datatype: :integer}],
        [12,:invln_mid, :mid, "Mid", {datatype: :string}],
        [13,:invln_middle_charge, :middleman_charge, "Middleman Charge", {datatype: :decimal}],
        [14,:invln_net_weight, :net_weight, "Net Weight", {datatype: :decimal}],
        [15,:invln_net_weight_uom, :net_weight_uom, "Net Weight UOM", {datatype: :string}],
        [16,:invln_part_description, :part_description, "Part Description", {datatype: :string}],
        [17,:invln_part_number, :part_number, "Part Number", {datatype: :string}],
        [18,:invln_pieces, :pieces, "Pieces", {datatype: :decimal}],
        [19,:invln_po_number, :po_number, "PO Number", {datatype: :string}],
        [20,:invln_quantity, :quantity, "Quantity", {datatype: :decimal}],
        [21,:invln_quantity_uom, :quantity_uom, "Quantity UOM", {datatype: :string}],
        [22,:invln_trade_discount, :trade_discount, "Discount - Trade", {datatype: :decimal}],
        [23,:invln_unit_price, :unit_price, "Unit Price", {datatype: :decimal}],
        [24,:invln_value_domestic, :value_domestic, "Value - Domestic", {datatype: :decimal}],
        [25,:invln_value_foreign, :value_foreign, "Value - Foreign", {datatype: :decimal}],
        [26,:invln_volume, :volume, "Volume", {datatype: :decimal}],
        [27,:invln_volume_uom, :volume_uom, "Volume UOM", {datatype: :decimal}]
    ]
  end
end; end; end
