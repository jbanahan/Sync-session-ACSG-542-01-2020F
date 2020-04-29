require 'open_chain/s3'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/product_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberProductChangeComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::EntityCompare::ProductComparator

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Product'
    cdefs = my_custom_definitions
    old_data = build_data(get_json_hash(old_bucket, old_path, old_version), cdefs)
    new_data = build_data(get_json_hash(new_bucket, new_path, new_version), cdefs)
    process_merch_cat_description(id, old_data, new_data, cdefs)
  end

  def self.my_custom_definitions
    self.prep_custom_definitions [:prod_merch_cat, :prod_merch_cat_desc]
  end

  def self.build_data hash, cdefs
    return nil if hash.nil? || hash.empty?
    ProductData.new(hash, cdefs)
  end

  def self.process_merch_cat_description id, old_data, new_data, cdefs
    return if new_data.merch_cat_desc.blank?
    update_merch_cat_description(id, new_data, cdefs) if (old_data.nil? || old_data.merch_cat_desc!=new_data.merch_cat_desc)
  end

  def self.update_merch_cat_description id, new_data, cdefs
    return if new_data.merch_cat_desc.blank? || new_data.merch_cat.blank?
    ss = SearchSetup.new(user:User.integration, module_type:'Product')
    ss.search_criterions.build(model_field_uid:cdefs[:prod_merch_cat].model_field_uid.to_s, operator:'eq', value:new_data.merch_cat)
    ss.search_criterions.build(model_field_uid:cdefs[:prod_merch_cat_desc].model_field_uid.to_s, operator:'nq', value:new_data.merch_cat_desc)
    # this has to be in a transaction so the products that are updated don't fire out the delayed jobs to run their own change comparators
    # otherwise, you could have a race condition
    ActiveRecord::Base.transaction do
      SearchQuery.new(ss, ss.user).result_keys.each do |id_to_update|
        p = Product.find id_to_update
        p.update_custom_value!(cdefs[:prod_merch_cat_desc], new_data.merch_cat_desc)
        p.create_snapshot(User.integration)
      end
    end
  end

  class ProductData
    attr_reader :merch_cat, :merch_cat_desc
    def initialize hash, cdefs
      model_fields = hash['entity']['model_fields']
      @merch_cat = model_fields[cdefs[:prod_merch_cat].model_field_uid.to_s]
      @merch_cat_desc = model_fields[cdefs[:prod_merch_cat_desc].model_field_uid.to_s]
    end
  end
end; end; end; end
