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
    return ["711311", "711319", "711320", "711620"].include?(prod_hts[0..5]) ? 'spe' : nil
  end

  def is_bjt?(prod_hts)
    return nil if prod_hts.blank?
    return ["711711", "711719", "711790"].include?(prod_hts[0..5]) ? 'bjt' : nil
  end

  def is_nct?(product)
    product.get_custom_value(cdefs[:cites]).value == false && product.get_custom_value(cdefs[:fish_wildlife]).value == true ? 'nct' : nil
  end

  def is_fur?(prod_hts)
    return nil if prod_hts.blank?
    return prod_hts[0..1] == '43' ? 'fur' : nil
  end

  def is_cites?(product)
    product.get_custom_value(cdefs[:cites]).value ? 'cts' : nil
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
        "cts" => {"cts" => "cts", "spe" => "cts", "bjt" => "cts", "nct" => "cts", "wod" => "cts", "stw" => "cts", "fur" => "cts"},
        "spe" => {"cts" => "cts", "spe" => "spe", "bjt" => "nct", "nct" => "spe", "wod" => "spe", "stw" => "spe", "fur" => "spe"},
        "bjt" => {"cts" => "cts", "spe" => "spe", "bjt" => "bjt", "nct" => "nct", "wod" => "bjt", "stw" => "bjt", "fur" => "bjt"},
        "nct" => {"cts" => "cts", "spe" => "nct", "bjt" => "nct", "nct" => "nct", "wod" => "nct", "stw" => "nct", "fur" => "nct"},
        "wod" => {"cts" => "cts", "spe" => "spe", "bjt" => "bjt", "nct" => "nct", "wod" => "wod", "stw" => "wod", "fur" => "fur"},
        "stw" => {"cts" => "cts", "spe" => "spe", "bjt" => "bjt", "nct" => "nct", "wod" => "wod", "stw" => "stw", "fur" => "fur"},
        "fur" => {"cts" => "cts", "spe" => "spe", "bjt" => "bjt", "nct" => "nct", "wod" => "fur", "stw" => "fur", "fur" => "fur"},
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
