require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; module LumberCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    sap_company:{label:'SAP Company #',data_type: :string, module_type:'Company'}
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
