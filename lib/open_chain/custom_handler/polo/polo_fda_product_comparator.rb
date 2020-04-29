require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/product_comparator/product_comparator_helper'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class PoloFdaProductComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::EntityCompare::ProductComparator
  extend OpenChain::EntityCompare::ProductComparator::ProductComparatorHelper
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type == 'Product'
    old_prod_json = get_json_hash(old_bucket, old_path, old_version)
    new_prod_json = get_json_hash(new_bucket, new_path, new_version)
    return if tariffs_identical? old_prod_json, new_prod_json
    cdef = prep_custom_definitions([:prod_fda_indicator])[:prod_fda_indicator]
    old_indicator = mf(old_prod_json, "*cf_#{cdef.id}")
    new_indicator = fda_indicator_from_product new_prod_json
    assign_fda_field id, cdef, new_indicator unless old_indicator == new_indicator
  end

  def self.fda_indicator_from_product product_json
    tariffs = get_country_tariffs product_json, "US"
    return nil if tariffs.empty?
    us_official_tariffs = OfficialTariff.where(country_id: Country.where(iso_code: "US"), hts_code: tariffs)
                                        .where("fda_indicator LIKE '%FD1%' OR fda_indicator LIKE '%FD2%'")
    fda_indicator_from_tariffs tariffs, us_official_tariffs
  end

  def self.fda_indicator_from_tariffs tariffs, us_official_tariffs
    polo_fda_indicator = nil
    tariffs.find do |t|
      fda_indicator = us_official_tariffs.find { |ot| ot.hts_code == t }.try(:fda_indicator)
      polo_fda_indicator = extract_polo_indicator fda_indicator
    end
    polo_fda_indicator
  end

  def self.extract_polo_indicator fda_indicator_field
    fda_indicator_field ? fda_indicator_field.split("\n ").find { |fi| ["FD1", "FD2"].include? fi  } : nil
  end

  def self.tariffs_identical? fst_prod_json, snd_prod_json
    fst_prod_tariffs = (get_country_tariffs fst_prod_json, "US").uniq.sort
    snd_prod_tariffs = (get_country_tariffs snd_prod_json, "US").uniq.sort
    fst_prod_tariffs == snd_prod_tariffs
  end

  def self.assign_fda_field prod_id, cdef, value
    prod = Product.find prod_id
    prod.update_custom_value!(cdef, value)
    prod.create_snapshot User.integration, nil, "Polo FDA Comparator"
  end

end; end; end; end;