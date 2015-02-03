require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module VfitrackCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    shpln_po: {label:'PO Number',data_type: :string, module_type: 'ShipmentLine'},
    shpln_sku: {label:'SKU',data_type: :string, module_type: 'ShipmentLine'},
    shpln_coo: {label:'Country of Origin ISO',data_type: :string, module_type: 'ShipmentLine'},
    shpln_color: {label:'Color',data_type: :string, module_type: 'ShipmentLine'},
    shpln_desc: {label:'Description',data_type: :string, module_type: 'ShipmentLine'},
    shpln_received_date: {label:'Received Date',data_type: :date, module_type: 'ShipmentLine'},
    shpln_uom: {label:'UOM',data_type: :string, module_type: 'ShipmentLine'},
    shpln_size: {label:'Size',data_type: :string, module_type: 'ShipmentLine'},
    prod_part_number: {label: 'Part Number', data_type: :string, module_type: 'Product'},
    shpln_size: {label:'Size',data_type: :string, module_type: 'ShipmentLine'},
    prod_country_of_origin: {label: "Country of Origin", data_type: :string, module_type: "Product"},
    prod_fda_product: {label: "FDA Product?", data_type: :boolean, module_type: "Product"},
    prod_fda_product_code: {label: "FDA Product Code", data_type: :string, module_type: "Product"},
    prod_fda_temperature: {label: "FDA Temperature", data_type: :string, module_type: "Product"},
    prod_fda_uom: {label: "FDA Reporting UOM", data_type: :string, module_type: "Product"},
    prod_fda_country: {label: "FDA Product Country", data_type: :string, module_type: "Product"},
    prod_fda_mid: {label: "FDA MID", data_type: :string, module_type: "Product"},
    prod_fda_shipper_id: {label: "FDA Shipper ID", data_type: :string, module_type: "Product"},
    prod_fda_description: {label: "FDA Description", data_type: :string, module_type: "Product"},
    prod_fda_establishment_no: {label: "FDA Establishment #", data_type: :string, module_type: "Product"},
    prod_fda_container_length: {label: "FDA Container Length", data_type: :string, module_type: "Product"},
    prod_fda_container_width: {label: "FDA Container Width", data_type: :string, module_type: "Product"},
    prod_fda_container_height: {label: "FDA Container Height", data_type: :string, module_type: "Product"},
    prod_fda_contact_name: {label: "FDA Contact Name", data_type: :string, module_type: "Product"},
    prod_fda_contact_phone: {label: "FDA Contact Phone", data_type: :string, module_type: "Product"},
    prod_fda_affirmation_compliance: {label: "FDA Affirmation of Compliance", data_type: :string, module_type: "Product"},
    class_customs_description: {label: "Customs Description", data_type: :string, module_type: "Classification"},
    class_set_type: {label: "Set Type", data_type: :string, module_type: "Classification"},
    ord_invoicing_system: {label: "Invoicing System", data_type: :string, module_type: "Order"},
    ord_invoiced: {label: "Invoice Received?", data_type: :boolean, module_type: "Order"}
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
end; end; end
