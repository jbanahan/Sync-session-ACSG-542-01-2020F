require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module UnderArmour; module UnderArmourCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    po: {label:'PO Number',data_type: :string, module_type: 'ShipmentLine'},
    del_date: {label:'Delivery Date',data_type: :date, module_type: 'Shipment'},
    coo: {label:'Country of Origin',data_type: :string, module_type: 'ShipmentLine'},
    color: {label:'Color',data_type: :string, module_type: 'ShipmentLine'},
    size: {label:'Size',data_type: :string, module_type: 'ShipmentLine'}
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
