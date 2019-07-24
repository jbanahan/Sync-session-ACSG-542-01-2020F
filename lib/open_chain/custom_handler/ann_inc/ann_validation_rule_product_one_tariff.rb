require 'open_chain/custom_handler/ann_inc/ann_ftz_validation_helper'

# Fail if Classification Type isn't set and more than one tariff exists
module OpenChain; module CustomHandler; module AnnInc class AnnValidationRuleProductOneTariff < BusinessValidationRule
  include OpenChain::CustomHandler::AnnInc::AnnFtzValidationHelper

  def run_validation product
    cl = product.classifications.find_by country_id: us.id
    if cl && cl.tariff_records.count > 1 && !CLASSIFICATION_TYPES.include?(cl.custom_value(cdefs[:classification_type]))
      return "If Classification Type has not been set, only one HTS Classification should exist."
    end
    nil
  end

end; end; end; end
