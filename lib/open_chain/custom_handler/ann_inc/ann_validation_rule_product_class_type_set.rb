require 'open_chain/custom_handler/ann_inc/ann_ftz_validation_helper'

# Fail if 'Manual Entry Processing' is filled but 'Classification Type' is blank
module OpenChain; module CustomHandler; module AnnInc; class AnnValidationRuleProductClassTypeSet < BusinessValidationRule
  include OpenChain::CustomHandler::AnnInc::AnnFtzValidationHelper

  def run_validation product
    cl = product.classifications.find_by country_id: us.id
    if cl&.custom_value(cdefs[:manual_flag])
      if !CLASSIFICATION_TYPES.include? cl.custom_value(cdefs[:classification_type])
        return "If the Manual Entry Processing checkbox is checked, Classification Type is required."
      end
    end
    nil
  end

end; end; end; end
