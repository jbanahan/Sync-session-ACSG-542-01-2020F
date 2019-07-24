require 'open_chain/custom_handler/ann_inc/ann_ftz_validation_helper'

# Fail if 'Classification Type' is 'Multi' and any tariff is missing a 'Percent of Value'
module OpenChain; module CustomHandler; module AnnInc; class AnnValidationRuleProductTariffPercentOfValueSet < BusinessValidationRule
  include OpenChain::CustomHandler::AnnInc::AnnFtzValidationHelper

  def run_validation product
    bad_tariffs = []
    cl = product.classifications.find_by country_id: us.id

    if cl&.custom_value(cdefs[:classification_type]) == "Multi"
      cl.tariff_records.each do |tr|
        bad_tariffs << {country: cl.country.name, line: tr.line_number} unless percent_of_value_filled(tr)
      end
    end

    return nil if bad_tariffs.empty?
    tariff_str = bad_tariffs.map{ |t| "#{t[:country]}, line #{t[:line]}" }.join("\n")
    %Q(If Classification Type equals "Multi", Percent of Value is a required field.\n#{tariff_str})
  end

  def percent_of_value_filled tr
    percent = tr.custom_value(cdefs[:percent_of_value])
    percent && percent > 0
  end

end; end; end; end 
