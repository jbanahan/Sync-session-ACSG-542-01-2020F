require 'open_chain/entity_compare/order_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnAcDateComparator
  extend OpenChain::EntityCompare::OrderComparator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport

  def self.accept?(snapshot)
    super
  end

  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    return unless type == 'Order'
    self.new.compare(id, new_bucket, new_path, new_version)
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:ordln_ac_date, :ord_ac_date])
  end

  def compare(id, new_bucket, new_path, new_version)
    change = false
    order = Order.find(id)
    json = get_json_hash(new_bucket, new_path, new_version)
    order_line_hashes = json_child_entities(json, "OrderLine")
    all_ac_dates = []

    order_line_hashes.each do |line_hash|
      all_ac_dates << mf(line_hash, cdefs[:ordln_ac_date].model_field_uid)
    end

    all_ac_dates.compact!
    all_ac_dates.sort!

    current_order_ac = mf(json, cdefs[:ord_ac_date].model_field_uid)

    if (current_order_ac.nil? && all_ac_dates.first.present?) || (current_order_ac.present? && all_ac_dates.first.present? && current_order_ac > all_ac_dates.first)
      order.find_and_set_custom_value(cdefs[:ord_ac_date], all_ac_dates.first)
      order.save!
      change = true
    end

    order.create_snapshot(User.integration) if change
  end
end; end; end; end

