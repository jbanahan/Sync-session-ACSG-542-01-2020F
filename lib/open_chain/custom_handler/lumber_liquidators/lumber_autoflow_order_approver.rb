require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberAutoflowOrderApprover
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  def self.process order
    u = find_or_create_autoflow_user
    cdefs = self.prep_custom_definitions([:prodven_risk,:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
    has_changes = false

    order.order_lines.each do |ol|
      line_changed = process_line(ol,cdefs,u)
      has_changes = true if line_changed
    end

    if has_changes

      # need to delay this so it runs in a different transaction than the
      # change comparator that calls this class
      order.delay.create_snapshot(u)
    end
    order
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
    # if it's approved by someone other than auto-flow, do nothing
    approved_by = ol.get_custom_value(cdefs[:ordln_pc_approved_by]).value
    approved_by = ol.get_custom_value(cdefs[:ordln_pc_approved_by_executive]).value unless approved_by

    return changed if approved_by && approved_by != autoflow_user.id

    risk_level = get_line_risk(ol,cdefs)
    # if it has auto-flow as it's risk
    if risk_level == 'Auto-Flow'
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
  private_class_method :process_line

  def self.get_line_risk ol, cdefs
    vendor = ol.order.vendor
    pva = ol.product.product_vendor_assignments.where(vendor_id:vendor.id).first
    return nil unless pva
    return pva.get_custom_value(cdefs[:prodven_risk]).value
  end
end; end; end; end
