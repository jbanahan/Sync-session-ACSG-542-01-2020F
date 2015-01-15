require 'open_chain/custom_handler/intacct/intacct_client'

module OpenChain; module CustomHandler; module Intacct; class IntacctDataPusher
  
  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access

    if !opts[:companies] || !opts[:companies].is_a?(Array) || opts[:companies].size == 0
      raise "The Job Schedule must include a 'companies' array in the Options field."
    end

    self.new.run(opts[:companies])
  end

  def initialize client = IntacctClient.new
    @api_client = client
  end

  def run companies
    push_checks companies
    push_receivables companies
    push_payables companies
  end

  def push_payables companies
    # If a payable has errors, it's likely because of some sort of setup needing to be done or other out of band work that
    # can't be automated.  We're reporting on these so we'll skip them until they've been cleared.
    IntacctPayable.where(intacct_upload_date: nil, intacct_errors: nil, company: companies).order("created_at ASC").pluck(:id).each do |id|
      begin
        payable = IntacctPayable.find id
        Lock.with_lock_retry(payable) do 
          # double checking the upload date just in case we're running multiple pushes at the same time
          if payable.intacct_upload_date.nil?
            # Find any checks associated with this payable file / vendor and include them so we can 
            # record the payments against the payable we're loading for the check.
            checks = IntacctCheck.where(company: payable.company, bill_number: payable.bill_number, vendor_number: payable.vendor_number, intacct_adjustment_key: nil).
                      where("intacct_payable_id = ? OR intacct_payable_id IS NULL", payable.id).all
            @api_client.send_payable payable, checks

            # Identify which payable the check was assocated with - this is mostly for ease of debugging should the need arise later
            if checks.size > 0
              IntacctCheck.where(id: checks.map(&:id)).update_all(intacct_payable_id: payable.id)
            end
          end
        end
      rescue => e
        e.log_me ["Failed to upload Intacct Payable id #{id}."]
      end
    end
  end

  def push_receivables companies
    # If a receivable has errors, it's likely because of some sort of setup needing to be done or other out of band work that
    # can't be automated.  We're reporting on these so we'll skip them until they've been cleared.
    IntacctReceivable.where(intacct_upload_date: nil, intacct_errors: nil, company: companies).order("created_at ASC").pluck(:id).each do |id|
      begin
        receivable = IntacctReceivable.find id
        Lock.with_lock_retry(receivable) do
          # double checking the upload date just in case we're running multiple pushes at the same time
          @api_client.send_receivable receivable if receivable.intacct_upload_date.nil?
        end
      rescue => e
        e.log_me ["Failed to upload Intacct Receivable id #{id}."]
      end
    end
  end

  def push_checks companies
    IntacctCheck.where(intacct_upload_date: nil, intacct_errors: nil, company: companies).order("created_at ASC").pluck(:id).each do |id|
      begin
        check = IntacctCheck.find id
        Lock.with_lock_retry(check) do
          # double checking the upload date just in case we're running multiple pushes at the same time
          if check.intacct_upload_date.nil?
            # If we've already uploaded a payable with the same file / suffix as this check, then we should indicate to the api client
            # that an account adjustment is needed at this time as well.
            payable_count = IntacctPayable.where(company: check.company, bill_number: check.bill_number, vendor_number: check.vendor_number, payable_type: IntacctPayable::PAYABLE_TYPE_BILL).
                        where("intacct_key IS NOT NULL AND intacct_upload_date IS NOT NULL").count

            @api_client.send_check check, (payable_count > 0)
          end
        end
      rescue => e
        e.log_me ["Failed to upload Intacct Check id #{id}."]
      end
    end
  end

end; end; end; end
