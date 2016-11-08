require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Hm; class HmSystemClassifyProductComparator
  extend OpenChain::EntityCompare::ProductComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.accept? snapshot
    super && snapshot.recordable.try(:importer).try(:system_code) == "HENNE" 
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type == 'Product'
    prod_hsh = get_json_hash(new_bucket, new_path, new_version)
    check_classification(prod_hsh) if mf(prod_hsh, "prod_imp_syscode") == "HENNE"
  end

  def self.check_classification prod_hsh
    ca_hts = TariffRecord.clean_hts get_hts(get_classi prod_hsh, "CA")
    if ca_hts.blank?
      us_hts = TariffRecord.clean_hts get_hts(get_classi prod_hsh, "US")
      return if us_hts.blank?
      new_ca_hts = DataCrossReference.find_us_hts_to_ca(us_hts, Company.where(system_code: "HENNE").first.id)
      if new_ca_hts
        prod_id = prod_hsh["entity"]["record_id"]
        update_product! prod_id, new_ca_hts
      end
    end
  end

  def self.update_product! prod_id, ca_hts
    ca = Country.where(iso_code: "CA").first
    prod = Product.find prod_id
    Product.transaction do
      classi = prod.classifications.where(country_id: ca.id).first_or_create!
      tr = classi.tariff_records.first_or_create!
      if tr.hts_1.blank?
        tr.update_attributes(hts_1: ca_hts)
        flag_cdef, descr_cdef = get_cdefs
        prod.update_custom_value!(flag_cdef, true)
        classi.update_custom_value!(descr_cdef, get_description("CA", ca_hts))
        prod.create_snapshot User.integration, nil, "HmSystemClassifyProductComparator"
      end
    end
  end

  private

  def self.get_cdefs
    cdefs = prep_custom_definitions([:prod_system_classified, :class_customs_description ])
    [cdefs[:prod_system_classified], cdefs[:class_customs_description]]
  end

  def self.get_classi prod_hsh, iso_code
    json_child_entities(prod_hsh, "Classification").find{|cl| mf(cl, "class_cntry_iso") == iso_code}
  end

  def self.get_description iso_code, hts
    OfficialTariff.joins(:country).where(:hts_code=>hts).where("countries.iso_code = ?", iso_code).first.try(:remaining_description)
  end

end; end; end; end