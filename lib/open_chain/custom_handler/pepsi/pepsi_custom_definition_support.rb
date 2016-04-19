require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Pepsi; module PepsiCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    class_add_cvd: {label: "ADD/CVD", data_type: :boolean, module_type: 'Classification'},
    class_customs_desc_override: {label: 'Customs Description Override', data_type: :text, module_type: 'Classification'},
    class_fta_name: {label: 'Free Trade Agreement', data_type: :string, module_type: 'Classification'},
    class_fta_end: {label: "Free Trade End Date", data_type: :date, module_type: 'Classification'},
    class_fta_start: {label: "Free Trade Start Date", data_type: :date, module_type: 'Classification'},
    class_fta_notes: {label: "Free Trade Notes", data_type: :text, module_type: 'Classification'},
    class_ior: {label: "IOR", data_type: :string, module_type: 'Classification'},
    class_ruling_number: {label: 'Ruling #', data_type: :string, module_type: 'Classification'},
    class_tariff_shift: {label: "Tariff Shift", data_type: :string, module_type: 'Classification'},
    class_val_content: {label: "Value Content", data_type: :string, module_type: 'Classification'},
    prod_base_customs_description: {label: 'Base Customs Description', data_type: :text, module_type:'Product'},
    prod_shipper_name: {label: "Shipper Name",  data_type: :string,  module_type: 'Product'},
    prod_prod_code: {label: "Product Code", data_type: :string, module_type: 'Product'},
    prod_us_broker: {label: "US Broker", data_type: :string, module_type: 'Product'},
    prod_us_alt_broker: {label: "US Alt Broker", data_type: :string, module_type: 'Product'},
    prod_alt_prod_code: {label: "Alt Product Code", data_type: :string, module_type: 'Product'},
    prod_coo: {label: "Country of Origin", data_type: :string, module_type: 'Product'},
    prod_tcsa: {label: "US - TCSA", data_type: :boolean, module_type: 'Product'},
    prod_recod: {label: 'US - Recon', data_type: :boolean, module_type: 'Product'},
    prod_first_sale: {label: 'US - First Sale', data_type: :boolean, module_type: 'Product'},
    prod_related: {label: 'US - Related Parties', data_type: :boolean, module_type: 'Product'},
    prod_fda_code: {label: 'US - FDA Code', data_type: :string, module_type: 'Product'},
    prod_fdc: {label: 'US - FD&C', data_type: :string, module_type: 'Product'},
    prod_fda_desc: {label: 'US - FDA Description', data_type: :string, module_type: 'Product'},
    prod_fda_reg: {label: 'US - FDA Registration', data_type: :string, module_type: 'Product'},
    prod_fda_pn: {label: 'US - FDA Prior Notice', data_type: :boolean, module_type: 'Product'},
    prod_fda_uom_1: {label: 'US - FDA UOM 1', data_type: :string, module_type: 'Product'},
    prod_fda_uom_2: {label: 'US - FDA UOM 2', data_type: :string, module_type: 'Product'},
    prod_fda_fce: {label: 'US - FDA FCE#', data_type: :string, module_type: 'Product'},
    prod_fda_sid: {label: 'US - FDA SID#', data_type: :string, module_type: 'Product'},
    prod_fda_dims: {label: 'US - FDA Product Dimensions', data_type: :string, module_type: 'Product'},
    prod_oga_1: {label: 'US - Other Agency 1', data_type: :string, module_type: 'Product'},
    prod_oga_2: {label: 'US - Other Agency 2', data_type: :string, module_type: 'Product'},
    prod_prog_code: {label: 'US - OGA Program Code', data_type: :string, module_type: 'Product'},
    prod_proc_code: {label: 'US - OGA Processing Code', data_type: :string, module_type: 'Product'},
    prod_indented_use: {label: 'US - OGA Indented Use', data_type: :string, module_type: 'Product'},
    prod_trade_name: {label: 'US - OGA Trade/Brand Name', data_type: :string, module_type: 'Product'},
    prod_cbp_mid: {label: 'US - CBP MID', data_type: :string, module_type: 'Product'},
    prod_fda_mid: {label: 'US - FDA MID',data_type: :string, module_type: 'Product'},
    prod_quaker_validated_by: {label: 'Validated By (Quaker)', data_type: :integer, module_type:'Product', is_user: true, read_only: true},
    prod_quaker_validated_date: {label: 'Validated By (Quaker)', data_type: :datetime, module_type:'Product', read_only: true}
  }

  def self.included(base)
    base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end
end; end; end; end
