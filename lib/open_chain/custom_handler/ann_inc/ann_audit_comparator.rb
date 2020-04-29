require 'open_chain/entity_compare/order_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnAuditComparator
  extend OpenChain::EntityCompare::OrderComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport

  def self.accept?(snapshot)
    super
  end

  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    return unless type == 'Order'
    self.new.compare(id)
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:ord_audit_initiated_by, :ord_audit_initiated_date, :ord_docs_required])
  end

  def compare(id)
    change = false
    order = Order.find(id)
    if order.get_custom_value(cdefs[:ord_audit_initiated_date]).value.present? && order.get_custom_value(cdefs[:ord_docs_required]).value.blank?
      order.find_and_set_custom_value(cdefs[:ord_docs_required], true)
      order.save!
      change = true
    end

    order.create_snapshot(User.integration) if change
  end
end; end; end; end

