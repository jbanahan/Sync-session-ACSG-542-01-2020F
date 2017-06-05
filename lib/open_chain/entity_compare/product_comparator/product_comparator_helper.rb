require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module EntityCompare; module ProductComparator; module ProductComparatorHelper
  extend ActiveSupport::Concern
  include OpenChain::EntityCompare::ComparatorHelper

  def get_hts classi_hsh
    tariff = json_child_entities(classi_hsh, "TariffRecord").first
    hts = tariff ? mf(tariff, "hts_hts_1") : nil

    if hts
      hts = hts.gsub(".", "")
    end

    hts
  end

  def get_all_hts classification
    hts = []
    json_child_entities(classification, "TariffRecord").each do |tariff|
      hts_1 = mf(tariff, "hts_hts_1").to_s.gsub(".", "")

      hts << hts_1 unless hts_1.blank?
    end
    hts
  end

  def get_classification product_json, country_iso
    classifications = json_child_entities product_json, "Classification"
    classifications.find {|c| mf(c, "class_cntry_iso") == country_iso}
  end

  def get_country_tariffs product_json, country_iso
    hts = []
    classification = get_classification(product_json, country_iso)
    if classification
      hts = get_all_hts(classification)
    end

    hts
  end

end; end; end; end