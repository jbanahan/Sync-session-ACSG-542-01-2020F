require 'open_chain/custom_handler/custom_definition_support'
module OpenChain
  module CustomHandler
    module Polo
      module PoloCustomDefinitionSupport
        extend ActiveSupport::Concern

        CUSTOM_DEFINITION_INSTRUCTIONS = {
          :bartho_customer_id=>{:label=>"Barthco Customer ID", :data_type=>:string, :module_type=>'Product'},
          :test_style=>{:label=>"Test Style", :data_type=>:string, :module_type=>'Product'},
          :set_type=>{:label=>"Set Type", :data_type=>:string, :module_type=>'Classification'}
        }

        included do |base|
          base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
        end
        
        module ClassMethods
          def prep_custom_definitions fields
            prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
          end
        end
      end
    end
  end
end
