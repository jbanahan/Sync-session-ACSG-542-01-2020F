require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberAutoflowOrderApprover
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  
  def self.process order, entity_snapshot: true
    u = find_or_create_autoflow_user
    cdefs = self.prep_custom_definitions([:prodven_risk,:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive,:ord_assigned_agent,:ordln_qa_approved_by,:ordln_qa_approved_date])
    has_changes = false

    order.order_lines.each do |ol|
      line_changed = process_line(ol,cdefs,u)
      has_changes = true if line_changed
    end

    if has_changes
      # This used to delay, so it wouldn't run in the same "transaction" as the change comparator,
      # the change comparator actually disables snapshots now, so I'm not delaying this any longer.
      order.create_snapshot(u, nil, "System Job: Autoflow Order Approver") if entity_snapshot
      return true
    else
      return false
    end

  end

  def self.find_or_create_autoflow_user
    u = User.find_by_username('autoflow')
    if !u
      u = Company.find_master.users.build
      u.username = 'autoflow'
      u.password = (0...10).map { ('0'..'z').to_a[rand(74)] }.join
      u.time_zone = "Eastern Time (US & Canada)"
      u.disallow_password = true
      u.order_view = true
      u.order_edit = true
      u.save!
    end
    u
  end
  private_class_method :find_or_create_autoflow_user

  def self.process_line ol, cdefs, autoflow_user
    changed = false
    changed = true if process_line_product_compliance(ol,cdefs,autoflow_user)
    changed = true if process_line_qa(ol,cdefs,autoflow_user)
    return changed
  end

  def self.process_line_qa ol, cdefs, autoflow_user
    should_be_autoflow = ol.order.get_custom_value(cdefs[:ord_assigned_agent]).value.blank?
    is_approved = !ol.get_custom_value(cdefs[:ordln_qa_approved_date]).value.blank?
    if !is_approved && should_be_autoflow
      ol.update_custom_value!(cdefs[:ordln_qa_approved_by],autoflow_user.id)
      ol.update_custom_value!(cdefs[:ordln_qa_approved_date],0.seconds.ago)
    end
    return false
  end

  def self.process_line_product_compliance ol, cdefs, autoflow_user
    changed = false
    # if it's approved by someone other than auto-flow, do nothing
    approved_by = ol.get_custom_value(cdefs[:ordln_pc_approved_by]).value
    approved_by = ol.get_custom_value(cdefs[:ordln_pc_approved_by_executive]).value unless approved_by

    return changed if approved_by && approved_by != autoflow_user.id

    risk_level = get_line_risk(ol,cdefs)
    # if it has auto-flow as it's risk
    if !risk_level.blank? && risk_level.match(/Auto-Flow/)
      # if it is not approved, then approve with auto-flow user
      if approved_by.blank?
        ol.update_custom_value!(cdefs[:ordln_pc_approved_by],autoflow_user.id)
        ol.update_custom_value!(cdefs[:ordln_pc_approved_date],0.seconds.ago)
        changed = true
      end
    else # if it does not have auto-flow as it's risk
      # if it is approved by auto-flow, then clear it
      if approved_by == autoflow_user.id
        ol.update_custom_value!(cdefs[:ordln_pc_approved_by],nil)
        ol.update_custom_value!(cdefs[:ordln_pc_approved_date],nil)
        changed = true
      end
    end
    return changed
  end
  private_class_method :process_line_product_compliance

  def self.get_line_risk ol, cdefs
    vendor = ol.order.vendor
    pva = ol.product.product_vendor_assignments.where(vendor_id:vendor.id).first
    return nil unless pva
    return pva.get_custom_value(cdefs[:prodven_risk]).value
  end
end; end; end; end
