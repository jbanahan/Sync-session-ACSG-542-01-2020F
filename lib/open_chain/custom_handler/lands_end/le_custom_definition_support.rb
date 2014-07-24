require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module LandsEnd; module LeCustomDefinitionSupport
  extend ActiveSupport::Concern

  CUSTOM_DEFINITION_INSTRUCTIONS = {
    :part_number=>{label: 'Part Number', data_type: :string, module_type: 'Product'},
    :suffix_indicator=>{label: "Suffix Indicator", data_type: :string, module_type: 'Product'},
    :exception_code=>{label: "Exception Code", data_type: :string, module_type: 'Product'},
    :suffix=>{label: "Suffix", data_type: :string, module_type: 'Product'},
    :comments=>{label: "Comments", data_type: :text, module_type: 'Product'}
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