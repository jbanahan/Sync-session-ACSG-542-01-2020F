require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour; module UnderArmourCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    del_date: {label:'Delivery Date',data_type: :date, module_type: 'Shipment', cdef_uid: "shp_delivery_date"},
    po: {label:'PO Number',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_po_number"},
    coo: {label:'Country of Origin',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_country_origin"},
    color: {label:'Color',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_color"},
    size: {label:'Size',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_size"},
    colors: {label:'Colors',data_type: :text, module_type: 'Product', cdef_uid: "prod_colors"},
    plant_codes: {label:'Plant Codes',data_type: :text, module_type: 'Product', cdef_uid: "prod_plant_codes"},
    prod_color: {label:'Color',data_type: :string, module_type: 'Product', cdef_uid: 'prod_color'},
    prod_seasons: {label:'Seasons',data_type: :text, module_type:'Product', cdef_uid: 'prod_seasons'},
    prod_export_countries: {label:'Export Countries',data_type: :text, module_type: 'Product', cdef_uid: 'prod_export_countries'},
    prod_import_countries: {label:'Import Countries',data_type: :text, module_type: 'Product', cdef_uid: 'prod_import_countries'},
    prod_style: {label: 'Style', data_type: :string, module_type:'Product', cdef_uid: 'prod_style'},
    prod_size_code: {label: 'Size', data_type: :string, module_type:'Product', cdef_uid: 'prod_size_code'},
    prod_size_description: {label: 'Descriptive Size', data_type: :string, module_type: 'Product', cdef_uid: 'prod_size_description'},
    prod_site_codes: {label: 'Site Codes', data_type: :text, module_type: 'Product', cdef_uid: 'prod_site_codes'},
    expected_duty_rate: {label: "Expected Duty Rate", data_type: :decimal, module_type: "Classification", cdef_uid: 'class_expected_duty_rate'},
    var_export_countries: {label:'Export Countries',data_type: :text, module_type: 'Variant', cdef_uid: 'var_export_countries'},
    var_import_countries: {label:'Import Countries',data_type: :text, module_type: 'Variant', cdef_uid: 'var_import_countries'}
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
