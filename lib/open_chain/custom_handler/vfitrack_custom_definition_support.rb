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
    shpln_size: {label:'Size',data_type: :string, module_type: 'ShipmentLine'}
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
