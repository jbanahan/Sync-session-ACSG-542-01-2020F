module OpenChain; module ModelFieldDefinition; module CommercialInvoiceLineFieldDefinition
  def add_commercial_invoice_line_fields
    add_fields CoreModule::COMMERCIAL_INVOICE_LINE, [
      [1,:cil_line_number,:line_number,"Line Number",{:data_type=>:integer}],
      [2,:cil_part_number,:part_number,"Part Number",{:data_type=>:string}],
      [4,:cil_po_number,:po_number,"PO Number",{:data_type=>:string}],
      [7,:cil_units,:quantity,"Units",{:data_type=>:decimal}],
      [8,:cil_uom,:unit_of_measure,"UOM",{:data_type=>:string}],
      [9,:cil_value,:value,"Value",{:data_type=>:decimal,:currency=>:other}],
      [10,:cil_mid,:mid,"MID",{:data_type=>:string}],
      [11,:cil_country_origin_code,:country_origin_code,"Country Origin Code",{:data_type=>:string}],
      [12,:cil_country_export_code,:country_export_code,"Country Export Code",{:data_type=>:string}],
      [13,:cil_related_parties,:related_parties,"Related Parties",{:data_type=>:boolean}],
      [14,:cil_volume,:volume,"Volume",{:data_type=>:decimal}],
      #The next 3 lines have the wrong prefix because they were accidentally deployed to production this way and may be used on
      #reports.  It only hurts readability, so don't change them.
      [15,:ent_state_export_code,:state_export_code,"State Export Code",{:data_type=>:string}],
      [16,:ent_state_origin_code,:state_origin_code,"State Origin Code",{:data_type=>:string}],
      [17,:ent_unit_price,:unit_price,"Unit Price",{:data_type=>:decimal}],
      [18,:cil_department,:department,"Department",{:data_type=>:string}],
      [19,:cil_hmf,:hmf,"HMF",{:data_type=>:decimal}],
      [20,:cil_mpf,:mpf,"MPF - Full",{:data_type=>:decimal}],
      [21,:cil_prorated_mpf,:prorated_mpf,"MPF - Prorated",{:data_type=>:decimal}],
      [22,:cil_cotton_fee,:cotton_fee,"Cotton Fee",{:data_type=>:decimal}],
      [23,:cil_contract_amount,:contract_amount,"Contract Amount",{:data_type=>:decimal,:currency=>:other}],
      [24,:cil_add_case_number,:add_case_number,"ADD Case Number",{:data_type=>:string}],
      [25,:cil_add_bond,:add_bond,"ADD Bond",{:data_type=>:boolean}],
      [26,:cil_add_case_value,:add_case_value,"ADD Value",{:data_type=>:decimal,:currency=>:other}],
      [27,:cil_add_duty_amount,:add_duty_amount,"ADD Duty",{:data_type=>:decimal,:currency=>:other}],
      [28,:cil_add_case_percent,:add_case_percent,"ADD Percentage",{:data_type=>:decimal}],
      [29,:cil_cvd_case_number,:cvd_case_number,"CVD Case Number",{:data_type=>:string}],
      [30,:cil_cvd_bond,:cvd_bond,"CVD Bond",{:data_type=>:boolean}],
      [31,:cil_cvd_case_value,:cvd_case_value,"CVD Value",{:data_type=>:decimal,:currency=>:other}],
      [32,:cil_cvd_duty_amount,:cvd_duty_amount,"CVD Duty",{:data_type=>:decimal,:currency=>:other}],
      [33,:cil_cvd_case_percent,:cvd_case_percent,"CVD Percentage",{:data_type=>:decimal}],
      [34,:cil_customer_reference, :customer_reference, "Customer Reference",{:data_type=>:string}],
      [35,:cil_vendor_name, :vendor_name, "Vendor Name",{:data_type=>:string}],
      [36,:cil_adjustments_amount, :adjustments_amount, "Adjustments Amount",{:data_type=>:decimal,:currency=>:other}],
      [37,:cil_adjusted_value, :adjusted_value, "Adjusted Value",{:data_type=>:decimal,:currency=>:other,
        :import_lambda=>lambda {|o,d| "Adjusted Value ignored. (read only)"},
        :export_lambda=>lambda {|obj| (obj.adjustments_amount ? obj.adjustments_amount : BigDecimal.new(0)) + (obj.value ? obj.value : BigDecimal.new(0))},
        :qualified_field_name=> "(ifnull(commercial_invoice_lines.adjustments_amount,0) + ifnull(commercial_invoice_lines.value,0))",
      }],
      [38,:cil_total_duty, :total_duty, "Total Duty", {:data_type=>:decimal,:currency=>:other,
        :import_lambda=>lambda {|o,d| "Total Duty ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.total_duty },
        :qualified_field_name=> "(SELECT ifnull(sum(total_duty_t.duty_amount), 0) FROM commercial_invoice_tariffs total_duty_t
          WHERE total_duty_t.commercial_invoice_line_id = commercial_invoice_lines.id)"
      }],
      [39,:cil_total_fees, :total_fees, "Total Fees", {:data_type=>:decimal,:currency=>:other,
        :import_lambda=>lambda {|o,d| "Total Fees ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.total_fees },
        :qualified_field_name=> "(SELECT ifnull(total_fees_l.prorated_mpf, 0) + ifnull(total_fees_l.hmf, 0) + ifnull(total_fees_l.cotton_fee, 0) FROM commercial_invoice_lines total_fees_l
          WHERE total_fees_l.id = commercial_invoice_lines.id)"
      }],
      [40,:cil_total_duty_plus_fees, :duty_plus_fees_amount, "Total Duty + Fees", {:data_type=>:decimal,:currency=>:other,
        :import_lambda=>lambda {|o,d| "Total Fees ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.duty_plus_fees_amount },
        :qualified_field_name=> "(SELECT ifnull(total_duty_fees_l.prorated_mpf, 0) + ifnull(total_duty_fees_l.hmf, 0) + ifnull(total_duty_fees_l.cotton_fee, 0) +
            (SELECT ifnull(sum(total_duty_fees_t.duty_amount), 0)
              FROM commercial_invoice_tariffs total_duty_fees_t
              WHERE total_duty_fees_t.commercial_invoice_line_id = commercial_invoice_lines.id)
          FROM commercial_invoice_lines total_duty_fees_l
          WHERE total_duty_fees_l.id = commercial_invoice_lines.id)"
      }],
      [41,:cil_customs_line_number, :customs_line_number, "Customs Line Number",{:data_type=>:integer}],
      [42,:cil_product_line, :product_line, "Product Line",{:data_type=>:string}],
      [43,:cil_visa_number, :visa_number, "Visa Number",{:data_type=>:string}],
      [44,:cil_visa_quantity, :visa_quantity, "Visa Quantity",{:data_type=>:decimal}],
      [45,:cil_visa_uom, :visa_uom, "Visa UOM",{:data_type=>:string}],
      [46,:cil_value_foreign,:value_foreign,'Value (Foreign)',{data_type: :decimal, currency: :other}],
      [47,:cil_currency,:currency,'Currency',{data_type: :string}],
      [48,:cil_store_name, :store_name, "Store Name",{data_type: :string}],
      [49,:cil_subheader_number, :subheader_number, "Subheader Number", {datatype: :integer}]
    ]
  end
end; end; end
