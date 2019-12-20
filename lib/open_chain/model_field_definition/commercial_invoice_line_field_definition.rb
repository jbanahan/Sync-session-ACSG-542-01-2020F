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
        :qualified_field_name=> "(SELECT ifnull(total_fees_l.prorated_mpf, 0) + ifnull(total_fees_l.hmf, 0) + ifnull(total_fees_l.cotton_fee, 0) + ifnull(total_fees_l.other_fees, 0) FROM commercial_invoice_lines total_fees_l
          WHERE total_fees_l.id = commercial_invoice_lines.id)"
      }],
      [40,:cil_total_duty_plus_fees, :duty_plus_fees_amount, "Total Duty + Fees", {:data_type=>:decimal,:currency=>:other,
        :import_lambda=>lambda {|o,d| "Total Fees ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.duty_plus_fees_amount },
        :qualified_field_name=> "(SELECT ifnull(total_duty_fees_l.prorated_mpf, 0) + ifnull(total_duty_fees_l.hmf, 0) + ifnull(total_duty_fees_l.cotton_fee, 0) + ifnull(total_duty_fees_l.other_fees, 0) +
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
      [49,:cil_subheader_number, :subheader_number, "Subheader Number", {data_type: :integer}],
      [50, :cil_fda_review_date, :fda_review_date, "FDA Review Date", {data_type: :datetime}],
      [51, :cil_fda_hold_date, :fda_hold_date, "FDA Hold Date", {data_type: :datetime}],
      [52, :cil_fda_release_date, :fda_release_date, "FDA Release Date", {data_type: :datetime}],
      [53, :cil_first_sale, :contract_amount, "First Sale", {:data_type => :boolean, :read_only=>true,
        :import_lambda=>lambda{|o,d| "First Sale ignored. (read only)" },
        :export_lambda=>lambda{|obj| (obj.contract_amount.present? && obj.contract_amount > 0) || obj.value_appraisal_method == "F" },
        :qualified_field_name=> "IF(contract_amount > 0 OR value_appraisal_method = 'F', true, false)"
      }],
      [54, :cil_value_appraisal_method, :value_appraisal_method, "Value Appraisal Method", {data_type: :string}],
      [55, :cil_first_sale_savings, :first_sale_savings, "First Sale Savings", {data_type: :decimal, :read_only=>true,
        :import_lambda=>lambda{|o,d| "First Sale Savings ignored (read only)"},
        :export_lambda=>lambda { |obj| obj.first_sale_savings },
        :qualified_field_name=>"IF(contract_amount IS NULL OR contract_amount = 0, 0,
                                    (SELECT ROUND((cil.contract_amount - cil.value) * (cit.duty_amount / cit.entered_value), 2)
                                     FROM commercial_invoice_lines cil
                                       INNER JOIN commercial_invoice_tariffs cit ON cil.id = cit.commercial_invoice_line_id
                                     WHERE cil.id = commercial_invoice_lines.id
                                     LIMIT 1 ))"
      }],
      [56, :cil_first_sale_difference, :first_sale_difference, "First Sale Difference", {data_type: :decimal, :read_only=>true,
        :import_lambda=>lambda{|o,d| "First Sale Difference ignored (read only)"},
        :export_lambda=>lambda { |obj| obj.first_sale_difference },
        :qualified_field_name=>"IF(contract_amount IS NULL OR contract_amount = 0, 0, ROUND((commercial_invoice_lines.contract_amount - commercial_invoice_lines.value), 2))"
      }],
      [57, :cil_con_container_number, :container_number, "Container Number", {:data_type=>:string, :read_only=>true,
        :import_lambda=>lambda{ |o,d| "Container Number ignored (read only)"},
        :export_lambda=>lambda{ |obj| obj.container.try(:container_number) },
        :qualified_field_name=> "(SELECT container_number FROM containers where containers.id = commercial_invoice_lines.container_id)"
        }],
      [58, :cil_non_dutiable_amount, :non_dutiable_amount, "Non-Dutiable Amount", {data_type: :decimal, currency: :usd}],
      [59, :cil_contract_amount_unit_price, :cil_contract_amount_unit_price, "Contract Amount / Unit", {data_type: :decimal, read_only: true,
        import_lambda: lambda {|o,d| "Contract Amount / Unit ignored (read only)"},
        export_lambda: lambda {|obj| obj.first_sale_unit_price },
        # Purposefully allowing for null values here because if quantity or contract amount is null I want this value to also be null
        qualified_field_name: "ROUND((commercial_invoice_lines.contract_amount / commercial_invoice_lines.quantity), 2)"
        }],
      [60, :cil_other_fees, :other_fees, "Other Taxes & Fees", {data_type: :decimal, currency: :usd}],
      [61, :cil_miscellaneous_discount, :miscellaneous_discount, "Miscellaneous Discount", {data_type: :decimal, currency: :usd}],
      [62, :cil_freight_amount, :freight_amount, "Freight Amount", {data_type: :decimal, currency: :usd}],
      [63, :cil_other_amount, :other_amount, "Other Adjustments", {data_type: :decimal, currency: :usd}],
      [64, :cil_cash_discount, :cash_discount, "Cash Discount", {data_type: :decimal, currency: :usd}],
      [65, :cil_add_to_make_amount, :add_to_make_amount, "Additions to Value", {data_type: :decimal, currency: :usd}],
      [66, :cil_agriculture_license_number, :agriculture_license_number, "Agriculture License Number", {data_type: :string}],
      [67, :cil_add_to_make_amount, :add_to_make_amount, "Additions to Value", {data_type: :decimal, currency: :usd}],
      [68, :cil_psc_reason_code, :psc_reason_code, "PSC Reason Code", {data_type: :string}],
      [69, :cil_psc_date, :psc_date, "PSC Date", {data_type: :datetime}],
      [70, :cil_tariff_quota, :cil_tariff_quota, "Tariff Quota", {data_type: :integer, read_only: true,
                                                                  export_lambda: lambda do |obj|
                                                                    obj.commercial_invoice_tariffs.where('quota_category IS NOT NULL AND quota_category <> 0').first&.quota_category
                                                                  end,
                                                                  qualified_field_name: "(SELECT quota_category FROM commercial_invoice_tariffs WHERE commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id AND (quota_category IS NOT NULL AND quota_category <> 0)  LIMIT 1)"
      }],
      [71, :cil_tariff_value_for_tax, :tariff_value_for_tax, "Value for Tax",{
        data_type: :decimal,
        read_only: true,
        import_lambda: lambda{ |obj, data| "Invoice Line - Value for Tax ignored. (read only)" },
        export_lambda: lambda{|obj| obj.value_for_tax },
        qualified_field_name: <<-SQL
          (SELECT sum(
            IFNULL(commercial_invoice_tariffs.entered_value,0) + 
            IFNULL(commercial_invoice_tariffs.duty_amount,0) + 
            IFNULL(commercial_invoice_tariffs.sima_amount,0) + 
            IFNULL(commercial_invoice_tariffs.excise_amount,0))
          FROM commercial_invoice_tariffs 
          WHERE commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id 
            AND commercial_invoice_tariffs.value_for_duty_code IS NOT NULL)
        SQL
        }],
      [72, :cil_entered_value_7501, :entered_value_7501, "7501 Entered Value", {data_type: :integer}]
    ]
  end
end; end; end
