require 'open_chain/custom_handler/ann_inc/ann_ftz_validation_helper'

# Fail if 'Classification Type' is 'Multi' and tariff 'Percent of Value' fields don't add to 100 
module OpenChain; module CustomHandler; module AnnInc; class AnnValidationRuleProductTariffPercentsAddTo100 < BusinessValidationRule
  include OpenChain::CustomHandler::AnnInc::AnnFtzValidationHelper

  def run_validation product
    product.classifications.each do |cl|
      next unless cl.custom_value(cdefs[:classification_type]) == "Multi"
      total = 0
      cl.tariff_records.each do |tr|
        percent = tr.custom_value(cdefs[:percent_of_value])
        total += percent if percent
      end
      if total != 100
        return "The sum of all Percent of Value fields for a Style should equal 100%."
      end
    end
  
    nil
  end

end; end; end; end
