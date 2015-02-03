require 'open_chain/custom_handler/custom_definition_support'
module OpenChain; module CustomHandler; module Rhee; module RheeCustomDefinitionSupport
  extend ActiveSupport::Concern

  CUSTOM_DEFINITION_INSTRUCTIONS = {
    fda_product_code: {label: "FDA Product Code", data_type: :string, module_type: 'Product'}
  }

  included do |base|
    base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
  end
  
  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end

end; end; end; end
