require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/product_vendor_assignment_comparator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberProductVendorAssignmentChangeComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::EntityCompare::ProductVendorAssignmentComparator

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='ProductVendorAssignment'
    risk_cdef = prep_custom_definitions([:prodven_risk])[:prodven_risk]
    new_risk = get_risk_value(risk_cdef,get_json_hash(new_bucket,new_path,new_version))
    old_risk = get_risk_value(risk_cdef,get_json_hash(old_bucket,old_path,old_version))

    if new_risk != old_risk && [new_risk, old_risk].any? {|m| m =~ /auto-flow/i}
      find_linked_orders(id).each do |ord|
        OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.process(ord)
      end
    end
  end

  def self.get_risk_value cdef, hash
    return if hash.blank?
    entity = hash['entity']
    return if entity.nil?
    model_fields = entity['model_fields']
    return if model_fields.nil?
    model_fields[cdef.model_field_uid.to_s]
  end
  private_class_method :get_risk_value

  def self.find_linked_orders pva_id
    pva = ProductVendorAssignment.find_by_id(pva_id)

    # running async so it could have been deleted in the interim
    return [] if pva.nil?

    Order.where(vendor_id: pva.vendor_id, closed_at: nil).where("id IN (SELECT order_id FROM order_lines WHERE order_lines.order_id = orders.id AND order_lines.product_id = ?)",pva.product_id)
  end
end; end; end; end
