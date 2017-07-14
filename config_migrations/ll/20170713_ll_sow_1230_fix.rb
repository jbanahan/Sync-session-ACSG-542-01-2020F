module ConfigMigrations; module LL; class LLSow1230Fix

  # The csv file given here is expected to be filled with orders that are already approved and we just 
  # need to adjust the terms to those given in the file and then reapprove the order.
  #
  # If an order is found to be approved when loaded, it will be skipped.
  # 
  # A CSV file consisting of Order DB ID, Order Number, Terms of Payment is expected.
  #
  def fix_approved_terms_and_reapprove file, log_file
    user = User.integration
    loop_file(file, log_file) do |log_file, order, terms|
      # If the order has gone back to unaccepted, then we shouldn't process it here
      # If the terms are identical to the "fixed" terms, then we also shouldn't process it, that means its been
      # updated already by the sap feed (and probably needs to get run through the other validation method)
      if !order.accepted_by_id.nil? && order.terms_of_payment != terms
        fix_terms_and_approve log_file, user, order, terms
      end
    end
  end

  # The csv file given here is expected to be filled with orders that are currently unapproved and we need
  # to check if they are 
  #
  # If an order is found to be unapproved when loaded, it will be skipped..it will also be unapproved
  # if it's found to have not been previously approved prior to the code deployment.
  # 
  # A CSV file consisting of Order DB ID, Order Number, Terms of Payment is expected.
  #
  def validate_previously_approved_fix_terms_and_approve file, log_file
    user = User.integration
    loop_file(file, log_file) do |log_file, order, terms|
      # We're only expected unapproved orders here, so if the order went to approved, then 
      # we don't have to mess with it...we also only want to adjust the terms on orders
      # that were approved prior to the 1230 deployment.
      if order.accepted_by_id.nil? && previously_approved?(order)
        fix_terms_and_approve log_file, user, order, terms
      end
      
    end
    nil
  end

  def loop_file(file, log_file)
    log_file = File.open(log_file, "a")
    begin
      CSV.foreach(file) do |row|
        id = row[0].to_i
        order_number = row[1].to_s.strip
        terms = row[2].to_s.strip

        next unless id > 0 && !terms.blank?

        order = Order.where(id: id).first

        next if order.nil? || order.order_number != order_number 

        yield log_file, order, terms
      end
    ensure
      log_file.flush
      log_file.close
    end
  end

  def fix_terms_and_approve log_file, user, order, terms
    existing_terms = order.terms_of_payment
    order.terms_of_payment = terms
    # Not using the full Order#accept! method, because we need to add a note to the snapshot
    order.accept_logic user
    order.save!
    log_file << [Time.zone.now, order.order_number, "Updated Terms from '#{existing_terms}' to '#{terms}' and maked order as re-approved using the 'Integration' user."].to_csv
    log_file.flush
    snapshot = order.create_snapshot user, nil, "Ticket #9313: Terms Fix Reapproval"
    snapshot.update_attributes! compared_at: Time.zone.now
  end

  def previously_approved? order
    cutoff_date = Time.zone.parse("2017-07-12 15:56:13.0")

    snapshot = order.entity_snapshots.where("created_at < ? ", cutoff_date).order("created_at DESC").limit(1)

    return false if snapshot.nil?

    !snapshot.snapshot_hash["entity"]["model_fields"]["ord_accepted_by"].blank?
  end

end; end; end