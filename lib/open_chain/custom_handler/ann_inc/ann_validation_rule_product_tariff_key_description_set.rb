require 'open_chain/custom_handler/ann_inc/ann_ftz_validation_helper'

# Fail if 'Classification Type' is filled and any tariff is missing a 'Key Description'
module OpenChain; module CustomHandler; module AnnInc; class AnnValidationRuleProductTariffKeyDescriptionSet < BusinessValidationRule
  include OpenChain::CustomHandler::AnnInc::AnnFtzValidationHelper

  def run_validation product
    bad_tariffs = []
    cl = product.classifications.find_by country_id: us.id
    
    if CLASSIFICATION_TYPES.include? cl&.custom_value(cdefs[:classification_type])
      cl.tariff_records.each do |tr|
        bad_tariffs << {country: cl.country.name, line: tr.line_number} unless key_description_filled(tr)
      end
    end

    return nil if bad_tariffs.empty?
    tariff_str = bad_tariffs.map{ |t| "#{t[:country]}, line #{t[:line]}" }.join("\n")
    %Q(If Classification Type equals "Multi" or "Decision", Key Description is a required field.\n#{tariff_str})
  end

  def key_description_filled tr
    tr.custom_value(cdefs[:key_description]).present?
  end

end; end; end; end
