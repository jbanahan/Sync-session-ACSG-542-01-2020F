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

  def run companies, checks_only: false, invoices_only: false
    push_checks(companies) unless invoices_only

    if !checks_only
      push_receivables companies
      push_payables companies
    end

    nil
  end

  # Pushes all the Receivables and Payables associated with this export object into Intacct.
  def self.push_billing_export_data export
    # Allow passing an export id so we can better support async jobs
    export = IntacctAllianceExport.where(id: export).first if export.is_a?(Numeric)

    pusher = self.new

    # We need to ensure the dimensions are present in intacct before pushing the actual data
    broker_files, freight_files = extract_dimensions(export)
    broker_files.each do |broker_file|
      pusher.push_dimension("Broker File", broker_file)
    end

    freight_files.each do |freight_file|
      pusher.push_dimension("Freight File", freight_file)
    end

    export.intacct_receivables.each do |ir|
      pusher.push_receivable(ir)
    end

    export.intacct_payables.each do |ip|
      pusher.push_payable(ip)
    end

    nil
  end

  def push_dimension dimension_type, dimension_code
    @api_client.send_dimension(dimension_type, dimension_code, dimension_code)
  end

  def push_payables companies
    # If a payable has errors, it's likely because of some sort of setup needing to be done or other out of band work that
    # can't be automated.  We're reporting on these so we'll skip them until they've been cleared.
    IntacctPayable.where(intacct_upload_date: nil, intacct_errors: nil, company: companies).order("created_at ASC").pluck(:id).each do |id|
      payable = IntacctPayable.find id
      push_payable payable
    end
  rescue StandardError => e
    e.log_me ["Failed to upload Intacct Payable id #{id}."]
  end

  def push_payable payable
    Lock.db_lock(payable) do
      # double checking the upload date just in case we're running multiple pushes at the same time
      if payable.intacct_upload_date.nil? && payable.intacct_errors.blank?
        # Find any checks associated with this payable file / vendor and include them so we can
        # record the payments against the payable we're loading for the check.
        checks = IntacctCheck.where(company: payable.company, bill_number: payable.bill_number, vendor_number: payable.vendor_number, intacct_adjustment_key: nil)
                             .where("intacct_payable_id = ? OR intacct_payable_id IS NULL", payable.id).to_a
        @api_client.send_payable payable, checks

        # Identify which payable the check was assocated with - this is mostly for ease of debugging should the need arise later
        if checks.size > 0
          IntacctCheck.where(id: checks.map(&:id)).update_all(intacct_payable_id: payable.id) # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end
  end

  def push_receivables companies
    # If a receivable has errors, it's likely because of some sort of setup needing to be done or other out of band work that
    # can't be automated.  We're reporting on these so we'll skip them until they've been cleared.
    IntacctReceivable.where(intacct_upload_date: nil, intacct_errors: nil, company: companies).order("created_at ASC").pluck(:id).each do |id|
      receivable = IntacctReceivable.find id
      push_receivable receivable
    end
  rescue StandardError => e
    e.log_me ["Failed to upload Intacct Receivable id #{id}."]
  end

  def push_receivable receivable
    Lock.db_lock(receivable) do
      # double checking the upload date just in case we're running multiple pushes at the same time
      @api_client.send_receivable receivable if receivable.intacct_upload_date.nil? && receivable.intacct_errors.blank?
    end
  end

  def push_checks companies
    IntacctCheck.where(intacct_upload_date: nil, intacct_errors: nil, company: companies).order("created_at ASC").pluck(:id).each do |id|
      check = IntacctCheck.find id
      push_check(check)
    end
  rescue StandardError => e
    e.log_me ["Failed to upload Intacct Check id #{id}."]
  end

  def push_check check
    Lock.db_lock(check) do
      # double checking the upload date just in case we're running multiple pushes at the same time
      if check.intacct_upload_date.nil?
        # If an adjustment wasn't already added for this check (could happen in cases where there were errors on the first upload that weren't cleared) AND
        # If we've already uploaded a payable with the same file / suffix as this check, then we should indicate to the api client
        # that an account adjustment is needed at this time as well.
        payable_count = 0
        if check.intacct_adjustment_key.nil?
          payable_count = IntacctPayable.where(company: check.company, bill_number: check.bill_number,
                                               vendor_number: check.vendor_number, payable_type: IntacctPayable::PAYABLE_TYPE_BILL)
                                        .where("intacct_key IS NOT NULL AND intacct_upload_date IS NOT NULL").count
        end

        @api_client.send_check check, (payable_count > 0)
      end
    end
  end

  class << self
    private

    def extract_dimensions export
      broker_files = Set.new
      # Technically, the freight files should be needed any longer, but who know's what'll happen in the
      # future, so I'll just support sending them too.
      freight_files = Set.new
      export.intacct_receivables.each do |ir|
        ir.intacct_receivable_lines.each do |l|
          broker_files << l.broker_file if l.broker_file.present?
          freight_files << l.freight_file if l.freight_file.present?
        end
      end

      export.intacct_payables.each do |ip|
        ip.intacct_payable_lines.each do |l|
          broker_files << l.broker_file if l.broker_file.present?
          freight_files << l.freight_file if l.freight_file.present?
        end
      end

      [broker_files, freight_files]
    end
  end

end; end; end; end
