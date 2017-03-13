require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Pepsi; module PepsiCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS ||= {
    class_add_cvd: {label: "ADD/CVD", data_type: :boolean, module_type: 'Classification', cdef_uid: "class_add_cvd"}, 
    class_audit: {label: "Classification Audit", data_type: :text, module_type:'Classification', cdef_uid: "class_audit"}, 
    class_customs_desc_override: {label: 'Customs Description Override', data_type: :text, module_type: 'Classification', cdef_uid: "class_customs_desc_override"}, 
    class_fta_criteria: {label: 'FTA Criteria', data_type: :string, module_type: 'Classification', cdef_uid: "class_fta_criteria"}, 
    class_fta_end: {label: "Free Trade End Date", data_type: :date, module_type: 'Classification', cdef_uid: "class_fta_end"}, 
    class_fta_name: {label: 'Free Trade Agreement', data_type: :string, module_type: 'Classification', cdef_uid: "class_fta_name"}, 
    class_fta_notes: {label: "Free Trade Notes", data_type: :text, module_type: 'Classification', cdef_uid: "class_fta_notes"}, 
    class_fta_start: {label: "Free Trade Start Date", data_type: :date, module_type: 'Classification', cdef_uid: "class_fta_start"}, 
    class_ior: {label: "IOR", data_type: :string, module_type: 'Classification', cdef_uid: "class_ior"}, 
    class_ruling_number: {label: 'Ruling #', data_type: :string, module_type: 'Classification', cdef_uid: "class_ruling_number"}, 
    class_tariff_shift: {label: "Tariff Shift", data_type: :string, module_type: 'Classification', cdef_uid: "class_tariff_shift"}, 
    class_val_content: {label: "Value Content", data_type: :string, module_type: 'Classification', cdef_uid: "class_val_content"}, 
    prod_alt_prod_code: {label: "Alt Product Code", data_type: :string, module_type: 'Product',rank:2200, cdef_uid: "prod_alt_prod_code"}, 
    prod_base_customs_description: {label: 'Base Customs Description', data_type: :text, module_type:'Product',rank:1500, cdef_uid: "prod_base_customs_description"}, 
    prod_cas_number: {label: 'CAS #', data_type: :string, module_type: 'Product', rank: 2000, cdef_uid: "prod_cas_number"}, 
    prod_cbp_mid: {label: 'US - CBP MID', data_type: :string, module_type: 'Product',rank:2800, cdef_uid: "prod_cbp_mid"}, 
    prod_coo: {label: "Country of Origin", data_type: :string, module_type: 'Product',rank:2300, cdef_uid: "prod_coo"}, 
    prod_eroom_link: {label: 'eRoom Link', data_type: :string, module_type: 'Product',rank:5, cdef_uid: "prod_eroom_link"}, 
    prod_fda_code: {label: 'US - FDA Code', data_type: :string, module_type: 'Product',rank:3600, cdef_uid: "prod_fda_code"}, 
    prod_fda_desc: {label: 'US - FDA Description', data_type: :string, module_type: 'Product',rank:3700, cdef_uid: "prod_fda_desc"}, 
    prod_fda_dims: {label: 'US - FDA Product Dimensions', data_type: :string, module_type: 'Product',rank:4200, cdef_uid: "prod_fda_dims"}, 
    prod_fda_fce: {label: 'US - FDA FCE#', data_type: :string, module_type: 'Product',rank:3900, cdef_uid: "prod_fda_fce"}, 
    prod_fda_mid: {label: 'US - FDA MID',data_type: :string, module_type: 'Product',rank:2900, cdef_uid: "prod_fda_mid"}, 
    prod_fda_pn: {label: 'US - FDA Prior Notice', data_type: :boolean, module_type: 'Product',rank:3400, cdef_uid: "prod_fda_pn"}, 
    prod_fda_reg: {label: 'US - FDA Registration #', data_type: :string, module_type: 'Product',rank:3000, cdef_uid: "prod_fda_reg"}, 
    prod_fda_sid: {label: 'US - FDA SID#', data_type: :string, module_type: 'Product',rank:3800, cdef_uid: "prod_fda_sid"}, 
    prod_fda_uom_1: {label: 'US - FDA UOM 1', data_type: :string, module_type: 'Product',rank:4000, cdef_uid: "prod_fda_uom_1"}, 
    prod_fda_uom_2: {label: 'US - FDA UOM 2', data_type: :string, module_type: 'Product',rank:4100, cdef_uid: "prod_fda_uom_2"}, 
    prod_fdc: {label: 'US - FD&C', data_type: :string, module_type: 'Product',rank:4300, cdef_uid: "prod_fdc"}, 
    prod_first_sale: {label: 'US - First Sale', data_type: :boolean, module_type: 'Product',rank:2500, cdef_uid: "prod_first_sale"}, 
    prod_fss_code: {label:'FSS Code',data_type: :string, module_type: 'Product', rank:1000, cdef_uid: "prod_fss_code"}, 
    prod_health_vet_cert: {label: 'US - Health/Vet Cert Required', data_type: :boolean, module_type: 'Product', rank:3500, cdef_uid: "prod_health_vet_cert"}, 
    prod_indented_use: {label: 'US - OGA Indented Use', data_type: :string, module_type: 'Product',rank:4500, cdef_uid: "prod_indented_use"}, 
    prod_oga_1: {label: 'US - Other Agency 1', data_type: :string, module_type: 'Product',rank:4700, cdef_uid: "prod_oga_1"}, 
    prod_oga_2: {label: 'US - Other Agency 2', data_type: :string, module_type: 'Product',rank:4800, cdef_uid: "prod_oga_2"}, 
    prod_oga_3: {label: 'US - Other Agency 3', data_type: :string, module_type: 'Product',rank:4900, cdef_uid: "prod_oga_3"}, 
    prod_proc_code: {label: 'US - OGA Processing Code', data_type: :string, module_type: 'Product',rank:4400, cdef_uid: "prod_proc_code"}, 
    prod_prod_code: {label: "Product Code", data_type: :string, module_type: 'Product',rank:2100, cdef_uid: "prod_prod_code"}, 
    prod_prog_code: {label: 'US - OGA Program Code', data_type: :string, module_type: 'Product',rank:4350, cdef_uid: "prod_prog_code"}, 
    prod_quaker_validated_by: {label: 'Validated By (Quaker)', data_type: :integer, module_type:'Product', is_user: true, read_only: true, cdef_uid: "prod_quaker_validated_by"}, 
    prod_quaker_validated_date: {label: 'Validated Date (Quaker)', data_type: :datetime, module_type:'Product', read_only: true, cdef_uid: "prod_quaker_validated_date"}, 
    prod_pgcs_validated_by: {label: 'Validated By (PGCS)', data_type: :integer, module_type:'Product', is_user: true, read_only: true, cdef_uid: "prod_pgcs_validated_by"}, 
    prod_pgcs_validated_date: {label: 'Validated Date (PGCS)', data_type: :datetime, module_type:'Product', read_only: true, cdef_uid: "prod_pgcs_validated_date"}, 
    prod_recod: {label: 'US - Recon', data_type: :boolean, module_type: 'Product',rank:2600, cdef_uid: "prod_recod"}, 
    prod_related: {label: 'US - Related Parties', data_type: :boolean, module_type: 'Product',rank:3100, cdef_uid: "prod_related"}, 
    prod_shipper_name: {label: "Shipper Name",  data_type: :string,  module_type: 'Product',rank:2700, cdef_uid: "prod_shipper_name"}, 
    prod_tcsa: {label: "US - TSCA", data_type: :boolean, module_type: 'Product',rank:2400, cdef_uid: "prod_tcsa"}, 
    prod_trade_name: {label: 'US - OGA Trade/Brand Name', data_type: :string, module_type: 'Product',rank:4600, cdef_uid: "prod_trade_name"}, 
    prod_us_alt_broker: {label: "US Alt Broker", data_type: :string, module_type: 'Product',rank:3300, cdef_uid: "prod_us_alt_broker"}, 
    prod_us_broker: {label: "US Broker", data_type: :string, module_type: 'Product',rank:3200, cdef_uid: "prod_us_broker"},
    prod_audited_by: {label: 'Audited By', data_type: :integer, module_type:'Product', is_user: true, read_only: true, cdef_uid: "prod_audited_by"},
    prod_audited_date: {label: 'Audited Date', data_type: :datetime, module_type:'Product', read_only: true, cdef_uid: "prod_audited_date"}
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
