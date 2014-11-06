require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module JJill; module JJillCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    vendor_style: {label:'Vendor Style', data_type: :string, module_type: 'Product'},
    color:{label:'Color',data_type: :string, module_type: 'OrderLine'},
    size:{label:'Size',data_type: :string, module_type: 'OrderLine'},
    fish_wildlife:{label:'Fish & Wildlife', data_type: :boolean, module_type: 'Product'}
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
