require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'

class LLRestoreVendorApproval
  include OpenChain::EntityCompare::ComparatorHelper

  def run order_ids, cut_off_date, reaccept: false
    message = "Vendor Approval Restore"
    user = User.integration
    logger = MonoLogger.new("log/ll_restore_approval.log")
    logger.level = Logger::DEBUG
    cutoff = cut_off_date.in_time_zone("UTC")

    Order.where(id: order_ids).each do |order|
      process_order(order, cutoff, reaccept, user, message, logger)
    end

    nil
  end


  def process_order order, snapshot_cutoff, re_accept, user, snapshot_message, logger
    return unless order.accepted_by.nil?

    # Find the first snapshot prior to the cutoff...if it has an approval, restore those values
    snapshot = order.entity_snapshots.where("created_at < ?", snapshot_cutoff).order("entity_snapshots.id desc").first

    if snapshot
      json = snapshot.snapshot_json

      accepted_date = mf(json, "ord_accepted_at")

      if accepted_date
        accepted_by = mf(json, "ord_accepted_by")
        accepted_by_user = User.where(username: accepted_by).first
        raise "Failed to find user #{accepted_by}" unless accepted_by_user
        approval = mf(json, "ord_approval_status")

        logger.info "Order id #{order.id} / '#{order.order_number}' was accepted at '#{accepted_date}' by '#{accepted_by}'/'#{accepted_by_user.id}' with status '#{approval}'."

        if re_accept
          order.accepted_at = accepted_date
          order.accepted_by = accepted_by_user
          order.approval_status = approval

          order.save!
          order.create_snapshot user, nil, snapshot_message
        end
      end
    end
  end

end