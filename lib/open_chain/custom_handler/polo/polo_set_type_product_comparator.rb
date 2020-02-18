require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain; module CustomHandler; module Polo; class PoloSetTypeProductComparator
  extend OpenChain::EntityCompare::ProductComparator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  attr_reader :set_type_cdef, :us_set_type

  def self.accept?(snapshot)
    super
  end

  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    set_type_cdef = prep_custom_definitions([:set_type])[:set_type]
    self.new(set_type_cdef).compare id, new_bucket, new_path, new_version
  end

  def initialize set_type_cdef
    @set_type_cdef = set_type_cdef
  end

  def compare id, bucket, path, version
    us_classi, other_classis = classifications bucket, path, version    
    @us_set_type = mf(us_classi, set_type_cdef.model_field_uid)
    
    classi_ids_to_update = ids_for_update(other_classis)
    update_product(id, classi_ids_to_update) if classi_ids_to_update.present?
  end
  
  private

  def classifications bucket, path, version
    json = get_json_hash bucket, path, version
    classis = json_child_entities(json, "Classification")
    us, others = classis.partition{ |hsh| mf(hsh, "class_cntry_iso") == "US" }
    [us.first, others]
  end

  def ids_for_update classi_hashes
    classi_hashes.select do |hsh| 
      (json_child_entities(hsh, "TariffRecord").count > 1) && (mf(hsh, set_type_cdef.model_field_uid) != us_set_type)
    end.map{ |hsh| hsh["record_id"] }
  end

  def update_product id, update_classi_ids
    prod = Product.includes(:classifications).find id
    update_classis = prod.classifications.select{ |cl| update_classi_ids.include? cl.id }
    update_classis.each { |cl| cl.find_and_set_custom_value(set_type_cdef, us_set_type) }
    prod.save!
    prod.create_snapshot User.integration, nil, "PoloSetTypeProductComparator"
  end

end; end; end; end
