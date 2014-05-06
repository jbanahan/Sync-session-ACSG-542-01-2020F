require 'open_chain/custom_handler/intacct/intacct_client'

module OpenChain; module CustomHandler; module Intacct; class IntacctDataPusher
  
  def self.run_schedulable opts = {}
    self.new.run(opts)
  end

  def initialize client = IntacctClient.new
    @api_client = client
  end

  def run opts
    push_receivables
    push_payables
  end

  def push_payables
    # If a payable has errors, it's likely because of some sort of setup needing to be done or other out of band work that
    # can't be automated.  We're reporting on these so we'll skip them until they've been cleared.
    IntacctPayable.where(intacct_upload_date: nil, intacct_errors: nil).order("created_at ASC").pluck(:id).each do |id|
      begin
        payable = IntacctPayable.find id
        Lock.with_lock_retry(payable) do 
          # double checking the upload date just in case we're running multiple pushes at the same time
          @api_client.send_payable payable if payable.intacct_upload_date.nil?
        end
      rescue => e
        e.log_me ["Failed to upload Intacct Payable id #{id}."]
      end
    end
  end

  def push_receivables
    # If a receivable has errors, it's likely because of some sort of setup needing to be done or other out of band work that
    # can't be automated.  We're reporting on these so we'll skip them until they've been cleared.
    IntacctReceivable.where(intacct_upload_date: nil, intacct_errors: nil).order("created_at ASC").pluck(:id).each do |id|
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

end; end; end; end
