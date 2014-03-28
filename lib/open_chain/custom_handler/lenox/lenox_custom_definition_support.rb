require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Lenox; module LenoxCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    part_number:{label:'Part Number',data_type: :string, module_type:'Product'},
    product_earliest_ship:{label:'Earliest Ship Date', data_type: :date, module_type:'Product'},
    product_group:{label:'Product Group',data_type: :string, module_type:'Product'},
    product_department:{label:'Department Name',data_type: :string, module_type:'Product'},
    product_pattern:{label:'Pattern',data_type: :string, module_type:'Product'},
    product_buyer_name:{label:'Buyer Name',data_type: :string, module_type:'Product'},
    product_units_per_set:{label:'Units Per Set',data_type: :integer, module_type:'Product'},
    product_coo:{label:'Country of Origin',data_type: :string, module_type:'Product'},
    order_line_note:{label:'Note',data_type: :string, module_type:'OrderLine'},
    order_buyer_name:{label:'Buyer',data_type: :string, module_type:'Order'},
    order_buyer_email:{label:'Buyer Email',data_type: :string, module_type:'Order'},
    order_destination_code:{label:'Final Destination',data_type: :string,module_type:'Order'},
    order_factory_code:{label:'Factory Code', data_type: :string, module_type:'Order'}
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
