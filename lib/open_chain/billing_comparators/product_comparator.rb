require 'open_chain/s3'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module BillingComparators; class ProductComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type == 'Product'
    new_snapshot_id = EntitySnapshot.where(bucket: new_bucket, doc_path: new_path, version: new_version).first.id
    args = {id: id, old_bucket: old_bucket, old_path: old_path, old_version: old_version, new_bucket: new_bucket, 
            new_path: new_path, new_version: new_version}.merge(new_snapshot_id: new_snapshot_id)
    check_new_classification args
  end

  def self.check_new_classification args
    new_bucket_classis = get_classifications(get_json_hash(args[:new_bucket], args[:new_path], args[:new_version]))
    old_bucket_classis = get_classifications(get_json_hash(args[:old_bucket], args[:old_path], args[:old_version]))
    new_classis = filter_new_classifications(old_bucket_classis, new_bucket_classis)
    
    new_classis.each do |classi|
      BillableEvent.create!(billable_eventable_type: "Classification", billable_eventable_id: classi[:id], 
                            entity_snapshot_id: args[:new_snapshot_id], event_type: "classification_new")
    end
  end

  def self.get_classifications product_hash
    classis = product_hash.presence ? (product_hash["entity"]["children"] || []) : []
    classis_with_hts = classis.select{ |classi| contains_hts_1? classi }
    classis_with_hts.map do |classi|
      {id: classi["entity"]["record_id"], iso_code: classi["entity"]["model_fields"]["class_cntry_iso"]}
    end
  end

  def self.contains_hts_1? class_hsh
    hts_1_found = false
    tariff_records = class_hsh["entity"]["children"] || []
    tariff_records.each do |t|
      hts = t["entity"]["model_fields"] || {}
      hts_1_found = true if hts["hts_hts_1"].presence
    end
    hts_1_found
  end

  def self.filter_new_classifications old_class_list, new_class_list
    old_iso_codes = old_class_list.map{ |o| o[:iso_code]}
    new_class_list.reject{ |n| old_iso_codes.include? n[:iso_code] }
  end

end; end; end