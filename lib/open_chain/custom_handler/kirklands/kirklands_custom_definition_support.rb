require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Kirklands; module KirklandsCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    prod_long_description: {label: "Long Description", data_type: :text, module_type: "Product", cdef_uid: "prod_long_description"},
    prod_material: {label: "Material", data_type: :string, module_type: "Product", cdef_uid: "prod_material"},
    prod_country_of_origin: {label: "Country of Origin", data_type: :string, module_type: "Product", cdef_uid: "prod_country_of_origin"},
    prod_additional_doc: {label: "Additional documentation required", data_type: :string, module_type: "Product", cdef_uid: "prod_additional_doc"},
    prod_fob_price: {label: "FOB Price", data_type: :decimal, module_type: "Product", cdef_uid: "prod_fob_price"},
    prod_fda_product: {label: "FDA Product?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_fda_product"},
    prod_fda_code: {label: 'US - FDA Code', data_type: :string, module_type: 'Product', cdef_uid: "prod_fda_code"},
    prod_tsca: {label: "TSCA", data_type: :boolean, module_type: "Product", cdef_uid: "prod_tsca"},
    prod_lacey: {label: "Lacey", data_type: :boolean, module_type: "Product", cdef_uid: "prod_lacey"},
    prod_part_number: {label: 'Vendor Item number', data_type: :string, module_type: 'Product', cdef_uid: "prod_part_number"},
    prod_add: {label: "ADD?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_add"},
    prod_add_case: {label: "ADD Case Number", data_type: :string, module_type: "Product", cdef_uid: "prod_add_case"},
    prod_cvd: {label: "CVD?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_cvd"},
    prod_cvd_case: {label: "CVD Case Number", data_type: :string, module_type: "Product", cdef_uid: "prod_cvd_case"},
    prod_vendor_item_number: {label: "Vendor Item Number", data_type: :string, module_type: "Product", cdef_uid: "prod_vendor_item_number"},
    ord_department: {label: "Department", data_type: :string, module_type: "Order", cdef_uid: "ord_department"},
    ord_department_code: {label: "Department Code", data_type: :string, module_type: "Order", cdef_uid: "ord_department_code"},
    ord_type: {label: "Type", data_type: :string, module_type: "Order", cdef_uid: "ord_type"}
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
