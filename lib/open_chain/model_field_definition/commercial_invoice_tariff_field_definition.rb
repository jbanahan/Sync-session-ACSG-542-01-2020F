module OpenChain; module ModelFieldDefinition; module CommercialInvoiceTariffFieldDefinition
  def add_commercial_invoice_tariff_fields
    add_fields CoreModule::COMMERCIAL_INVOICE_TARIFF, [
      [1,:cit_hts_code,:hts_code,"HTS Code",{:data_type=>:string,:export_lambda=>lambda{|t| t.hts_code.blank? ? "" : t.hts_code.hts_format}}],
      [2,:cit_duty_amount,:duty_amount,"Duty",{:data_type=>:decimal}],
      [3,:cit_entered_value,:entered_value,"Entered Value",{:data_type=>:decimal}],
      [4,:cit_spi_primary,:spi_primary,"SPI - Primary",{:data_type=>:string}],
      [5,:cit_spi_secondary,:spi_secondary,"SPI - Secondary",{:data_type=>:string}],
      [6,:cit_classification_qty_1,:classification_qty_1,"Quanity 1",{:data_type=>:decimal}],
      [7,:cit_classification_uom_1,:classification_uom_1,"UOM 1",{:data_type=>:string}],
      [8,:cit_classification_qty_2,:classification_qty_2,"Quanity 2",{:data_type=>:decimal}],
      [9,:cit_classification_uom_2,:classification_uom_2,"UOM 2",{:data_type=>:string}],
      [10,:cit_classification_qty_3,:classification_qty_3,"Quanity 3",{:data_type=>:decimal}],
      [11,:cit_classification_uom_3,:classification_uom_3,"UOM 3",{:data_type=>:string}],
      [12,:cit_gross_weight,:gross_weight,"Gross Weight",{:data_type=>:integer}],
      [13,:cit_tariff_description,:tariff_description,"Description",{:data_type=>:string}],
      [18,:ent_tariff_provision,:tariff_provision,"Tariff Provision",{:data_type=>:string}],
      [19,:ent_value_for_duty_code,:value_for_duty_code,"VFD Code",{:data_type=>:string}],
      [20,:ent_gst_rate_code,:gst_rate_code,"GST Rate Code",{:data_type=>:string}],
      [21,:ent_gst_amount,:gst_amount,"GST Amount",{:data_type=>:decimal}],
      [22,:ent_sima_amount,:sima_amount,"SIMA Amount",{:data_type=>:decimal}],
      [23,:ent_excise_amount,:excise_amount,"Excise Amount",{:data_type=>:decimal}],
      [24,:ent_excise_rate_code,:excise_rate_code,"Excise Rate Code",{:data_type=>:string}],
      [25,:cit_duty_rate,:duty_rate,"Duty Rate",{:data_type=>:decimal}],
      [26,:cit_quota_category,:quota_category,"Quota Category",{:data_type=>:integer}],
      [27,:cit_special_authority,:special_authority,"Special Authority",{:data_type=>:string}]
    ]
  end
end; end; end
