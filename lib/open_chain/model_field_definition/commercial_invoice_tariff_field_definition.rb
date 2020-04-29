module OpenChain; module ModelFieldDefinition; module CommercialInvoiceTariffFieldDefinition
  def add_commercial_invoice_tariff_fields
    add_fields CoreModule::COMMERCIAL_INVOICE_TARIFF, [
      [1, :cit_hts_code, :hts_code, "HTS Code", {
        :data_type=>:string,
        :export_lambda=>lambda {|t| t.hts_code.blank? ? "" : t.hts_code.hts_format},
        :search_value_preprocess_lambda=> hts_search_value_preprocess_lambda
      }],
      [2, :cit_duty_amount, :duty_amount, "Duty", {:data_type=>:decimal}],
      [3, :cit_entered_value, :entered_value, "Entered Value", {:data_type=>:decimal}],
      [4, :cit_spi_primary, :spi_primary, "SPI - Primary", {:data_type=>:string}],
      [5, :cit_spi_secondary, :spi_secondary, "SPI - Secondary", {:data_type=>:string}],
      [6, :cit_classification_qty_1, :classification_qty_1, "Quantity 1", {:data_type=>:decimal}],
      [7, :cit_classification_uom_1, :classification_uom_1, "UOM 1", {:data_type=>:string}],
      [8, :cit_classification_qty_2, :classification_qty_2, "Quantity 2", {:data_type=>:decimal}],
      [9, :cit_classification_uom_2, :classification_uom_2, "UOM 2", {:data_type=>:string}],
      [10, :cit_classification_qty_3, :classification_qty_3, "Quantity 3", {:data_type=>:decimal}],
      [11, :cit_classification_uom_3, :classification_uom_3, "UOM 3", {:data_type=>:string}],
      [12, :cit_gross_weight, :gross_weight, "Gross Weight", {:data_type=>:integer}],
      [13, :cit_tariff_description, :tariff_description, "Description", {:data_type=>:string}],
      [18, :ent_tariff_provision, :tariff_provision, "Tariff Provision", {:data_type=>:string}],
      [19, :ent_value_for_duty_code, :value_for_duty_code, "VFD Code", {:data_type=>:string}],
      [20, :ent_gst_rate_code, :gst_rate_code, "GST Rate Code", {:data_type=>:string}],
      [21, :ent_gst_amount, :gst_amount, "GST Amount", {:data_type=>:decimal}],
      [22, :ent_sima_amount, :sima_amount, "SIMA Amount", {:data_type=>:decimal}],
      [23, :ent_excise_amount, :excise_amount, "Excise Amount", {:data_type=>:decimal}],
      [24, :ent_excise_rate_code, :excise_rate_code, "Excise Rate Code", {:data_type=>:string}],
      [25, :cit_duty_rate, :duty_rate, "Duty Rate", {:data_type=>:decimal}],
      [26, :cit_quota_category, :quota_category, "Quota Category", {:data_type=>:integer}],
      [27, :cit_special_authority, :special_authority, "Special Authority", {:data_type=>:string}],
      [28, :cit_entered_value_7501, :entered_value_7501, "7501 Entered Value", {:data_type=>:integer}],
      [29, :cit_special_tariff, :special_tariff, "Special Tariff", {data_type: :boolean}],
      [30, :cit_duty_advalorem, :duty_advalorem, "Ad Valorem Duty", {data_type: :decimal}],
      [31, :cit_duty_specific, :duty_specific, "Specific Duty", {data_type: :decimal}],
      [32, :cit_duty_additional, :duty_additional, "Additional Duty", {data_type: :decimal}],
      [33, :cit_duty_other, :duty_other, "Other Duty", {data_type: :decimal}],
      [34, :cit_tariff_value_for_tax, :tariff_value_for_tax, "Value for Tax", {
        :data_type=>:decimal,
        :read_only=>true,
        :import_lambda => lambda { |obj, data| "Value for Tax ignored. (read only)" },
        :export_lambda => lambda { |t| t.value_for_tax },
        :qualified_field_name=> "IFNULL(commercial_invoice_tariffs.entered_value,0) +
            IFNULL(commercial_invoice_tariffs.duty_amount,0) +
            IFNULL(commercial_invoice_tariffs.sima_amount,0) +
            IFNULL(commercial_invoice_tariffs.excise_amount,0)"
        }],
      [35, :cit_advalorem_rate, :advalorem_rate, "Ad Valorem Duty Rate", {data_type: :decimal}],
      [36, :cit_specific_rate, :specific_rate, "Specific Duty Rate", {data_type: :decimal}],
      [37, :cit_specific_rate_uom, :specific_rate_uom, "Specific Duty Rate UOM", {data_type: :string}],
      [38, :cit_additional_rate, :additional_rate, "Additional Duty Rate", {data_type: :decimal}],
      [39, :cit_additional_rate_uom, :additional_rate_uom, "Additional Duty Rate UOM", {data_type: :decimal}],
      [40, :cit_sima_code, :sima_code, "SIMA Code", {data_type: :string}],
      [41, :cit_value_for_duty_code, :value_for_duty_code, "Value For Duty Code", {data_type: :string}]
    ]
  end
end; end; end
