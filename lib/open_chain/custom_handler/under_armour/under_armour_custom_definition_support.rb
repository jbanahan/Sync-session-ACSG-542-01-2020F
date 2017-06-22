require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour; module UnderArmourCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    po: {label:'PO Number',data_type: :string, module_type: 'ShipmentLine'},
    del_date: {label:'Delivery Date',data_type: :date, module_type: 'Shipment'},
    coo: {label:'Country of Origin',data_type: :string, module_type: 'ShipmentLine'},
    color: {label:'Color',data_type: :string, module_type: 'ShipmentLine'},
    colors: {label:'Colors',data_type: :text, module_type: 'Product'},
    plant_codes: {label:'Plant Codes',data_type: :text, module_type: 'Product'},
    import_countries: {label:'Import Countries',data_type: :text, module_type: 'Product'},
    size: {label:'Size',data_type: :string, module_type: 'ShipmentLine'},
    expected_duty_rate: {label: "Expected Duty Rate", data_type: :decimal, module_type: "Classification"},
    prod_color: {label:'Color',data_type: :string, module_type: 'Product', cdef_uid: 'prod_color'},
    prod_seasons: {label:'Seasons',data_type: :text, module_type:'Product'},
    prod_export_countries: {label:'Export Countries',data_type: :text, module_type: 'Product'},
    prod_import_countries: {label:'Import Countries',data_type: :text, module_type: 'Product', cdef_uid: 'prod_import_countries'},
    prod_style: {label: 'Style', data_type: :string, module_type:'Product', cdef_uid: :prod_style},
    prod_size_code: {label: 'Size', data_type: :string, module_type:'Product', cdef_uid: :prod_size_code},
    prod_size_description: {label: 'Descriptive Size', data_type: :string, module_type: 'Product', cdef_uid: 'prod_size_description'},
    prod_site_codes: {label: 'Site Codes', data_type: :text, module_type: 'Product', cdef_uid: 'prod_site_codes'},
    var_export_countries: {label:'Export Countries',data_type: :text, module_type: 'Variant'},
    var_import_countries: {label:'Import Countries',data_type: :text, module_type: 'Variant'}
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
