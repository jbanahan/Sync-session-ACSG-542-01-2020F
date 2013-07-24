require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
module OpenChain
  module CustomHandler
    module AnnInc
      class AnnZymAckFileHandler < OpenChain::CustomHandler::AckFileHandler
        include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport 
        
        def initialize
          @cdefs = prep_custom_definitions [:petite,:tall,:missy]
        end
        def find_product row
          p = Product.find_by_unique_identifier row[0]
          return p unless p.nil?
          @cdefs.each do |k,v|
            cv = CustomValue.where(:custom_definition_id=>v.id,:string_value=>row[0]).first
            p = cv.customizable if cv
            return p unless p.nil?
          end
          p
        end
      end
    end
  end
end
