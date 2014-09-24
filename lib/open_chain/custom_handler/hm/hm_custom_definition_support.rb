require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module Hm; module HmCustomDefinitionSupport
  extend ActiveSupport::Concern

  CUSTOM_DEFINITION_INSTRUCTIONS = {
    prod_part_number: {label: 'Part Number', data_type: :string, module_type: 'Product'},
    ol_dest_code:{label:'Destination Code',data_type: :string, module_type:'OrderLine'}
  }

  included do |base|
    base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
  end

  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end
end; end; end; end;