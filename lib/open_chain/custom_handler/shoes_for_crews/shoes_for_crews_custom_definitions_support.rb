require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module ShoesForCrews; module ShoesForCrewsCustomDefinitionsSupport
  extend ActiveSupport::Concern

  CUSTOM_DEFINITION_INSTRUCTIONS ||= {
    prod_part_number: {label: 'Part Number', data_type: :string, module_type: 'Product'},
    order_line_color:{label:'Color',data_type: :string, module_type: 'OrderLine'},
    order_line_size:{label:'Size',data_type: :string, module_type: 'OrderLine'},
    order_line_destination_code:{label:'Destination Code',data_type: :string, module_type:'OrderLine'}
  } 

  included do
    extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
  end

  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end

end; end; end; end