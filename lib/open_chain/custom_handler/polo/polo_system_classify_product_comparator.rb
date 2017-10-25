require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class PoloSystemClassifyProductComparator
  extend OpenChain::EntityCompare::ProductComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.accept?(snapshot)
    super
  end

  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    self.new.compare(id)
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:allocation_category, :cites, :fish_wildlife])
  end

  def compare(id)
    product = Product.find(id)
    existing_value = product.custom_value(cdefs[:allocation_category])

    classifications = collect_classifications(product)
    classification = calculate_classification(classifications)
    return if classification.blank?

    if existing_value != classification
      product.find_and_set_custom_value(cdefs[:allocation_category], classification)
      product.save!
      product.create_snapshot User.integration, nil, "Allocation Category Resolver"
    end
  end


  def is_spe?(prod_hts)
    return nil if prod_hts.blank?
    return ["711311", "711319", "711320", "711620"].include?(prod_hts[0..5]) ? 'SPE' : nil
  end

  def is_bjt?(prod_hts)
    return nil if prod_hts.blank?
    return ["711711", "711719", "711790"].include?(prod_hts[0..5]) ? 'BJT' : nil
  end

  def is_nct?(product)
    product.get_custom_value(cdefs[:cites]).value == false && product.get_custom_value(cdefs[:fish_wildlife]).value == true ? 'NCT' : nil
  end

  def is_fur?(prod_hts)
    return nil if prod_hts.blank?
    return prod_hts[0..1] == '43' ? 'FUR' : nil
  end

  def is_cites?(product)
    product.get_custom_value(cdefs[:cites]).value ? 'CTS' : nil
  end

  def collect_classifications(product)
    @country ||= Country.find_by_iso_code("IT")
    classifications = product.classifications.find_by_country_id(@country.id)
    prod_hts = nil
    if classifications
      prod_hts = classifications.tariff_records.first.try(:hts_1)
    end

    classifications = []

    classifications << is_bjt?(prod_hts)
    classifications << is_cites?(product)
    classifications << is_fur?(prod_hts)
    classifications << is_nct?(product)
    classifications << is_spe?(prod_hts)

    classifications.compact
  end

  def rules_table
    @rules_table ||= {
        "CTS" => {"CTS" => "CTS", "SPE" => "CTS", "BJT" => "CTS", "NCT" => "CTS", "WOD" => "CTS", "STW" => "CTS", "FUR" => "CTS"},
        "SPE" => {"CTS" => "CTS", "SPE" => "SPE", "BJT" => "NCT", "NCT" => "SPE", "WOD" => "SPE", "STW" => "SPE", "FUR" => "SPE"},
        "BJT" => {"CTS" => "CTS", "SPE" => "SPE", "BJT" => "BJT", "NCT" => "NCT", "WOD" => "BJT", "STW" => "BJT", "FUR" => "BJT"},
        "NCT" => {"CTS" => "CTS", "SPE" => "NCT", "BJT" => "NCT", "NCT" => "NCT", "WOD" => "NCT", "STW" => "NCT", "FUR" => "NCT"},
        "WOD" => {"CTS" => "CTS", "SPE" => "SPE", "BJT" => "BJT", "NCT" => "NCT", "WOD" => "WOD", "STW" => "WOD", "FUR" => "FUR"},
        "STW" => {"CTS" => "CTS", "SPE" => "SPE", "BJT" => "BJT", "NCT" => "NCT", "WOD" => "WOD", "STW" => "STW", "FUR" => "FUR"},
        "FUR" => {"CTS" => "CTS", "SPE" => "SPE", "BJT" => "BJT", "NCT" => "NCT", "WOD" => "FUR", "STW" => "FUR", "FUR" => "FUR"},
    }

    @rules_table
  end

  def calculate_classification(classifications)
    if classifications.present?
      classification = rules_table[classifications[0]][classifications[1]]

      return classification.present? ? classification : classifications[0]
    else
      return nil
    end
  end
end; end; end; end
