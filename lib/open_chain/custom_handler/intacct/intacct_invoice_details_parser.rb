module OpenChain; module CustomHandler; module Intacct; class IntacctInvoiceDetailsParser

  VFI_LMD_VENDOR_CODE ||= "LMD"
  LMD_VFI_CUSTOMER_CODE ||= "VANDE"
  VFI_COMPANY_CODE ||= 'vfc'
  LMD_COMPANY_CODE ||= 'lmd'

  def self.parse_query_results result_set
    self.new.parse(format_results(result_set))
  end

  def parse result_set
    # The value we're receiving here is a hash exactly like you'd get back from a raw SQL connection query execution
    # Be aware that the way Alliance stores and returns most string values includes a bunch of trailing spaces
    # Also, every value in the result set (dates and numbers) are strings.
    brokerage_receivable, lmd_receivable = extract_receivable_lines result_set

    # The payables are hashes hashed by vendor number and vendor reference
    brokerage_payables, lmd_payables = extract_payable_lines result_set

    IntacctAllianceExport.transaction do
      # Intacct requires that the broker file and freight file dimensions are in the system prior to 
      # uploading the payable/receivable information.  So we're tracking the numbers referenced in the 
      # referenced and will upload them immediately.

      lines = {:broker_file => [], :freight_file => []}
      br = create_receivable(brokerage_receivable, true) unless brokerage_receivable.empty?
      merge_file_numbers(lines, extract_file_numbers(br)) if br

      lr = create_receivable(lmd_receivable) unless lmd_receivable.empty?
      merge_file_numbers(lines, extract_file_numbers(lr)) if lr

      brokerage_payables.each_pair do |key, payable_lines|
        p = create_payable key, payable_lines
        merge_file_numbers(lines, extract_file_numbers(p))
      end

      lmd_payables.each_pair do |key, payable_lines|
        p = create_payable key, payable_lines
        merge_file_numbers(lines, extract_file_numbers(p))
      end

      lines[:broker_file].each do |bf|
        OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Broker File", bf, bf)
      end

      lines[:freight_file].each do |ff|
        OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Freight File", ff, ff)
      end

    end
    nil
  end

  def extract_receivable_lines result_set
    lmd_receivable = []
    brokerage_receivable = []

    result_set.each do |l|
      if lmd_division?(s(l["header division"]))
        lmd_receivable << l if l["print"] == "Y"
      else
        # A brokerage receivable line is any line that has a Print value of "Y"
        brokerage_receivable << l if l["print"] == "Y"

        # Any line on a brokerage invoice that has a line division of 11 or 12
        # is a receivable, as these represent the "pay through" process where our VFC company
        # pays the LMD company for the portion of the business they did on this file
        lmd_receivable << l if lmd_division?(s(l["line division"]))
      end
    end

    [brokerage_receivable, lmd_receivable]
  end

  def extract_payable_lines result_set
    # using a hash here to easily associate payables w/ a single vendor
    lmd_payables = Hash.new {|h, k| h[k] = []}
    brokerage_payables = Hash.new {|h, k| h[k] = []}

    result_set.each do |l|
      broker_invoice = !lmd_division?(s(l["header division"]))

      # A brokerage payable is any brokerage invoice line that has a vendor
      if broker_invoice 
        # Any line marked a payable is actually a payable
        if l["payable"] == "Y"
          brokerage_payables[payable_key(l)] << l
        elsif lmd_division?(s(l["line division"]))
          # If the division on the line is 11 or 12, then the line becomes a payable to the LMD division from 
          # the brokerage division (essentially the inverse of the LMD receivable lines)
          brokerage_payables[VFI_LMD_VENDOR_CODE] << l
        end
      else
        # If this is an lmd invoice, then every line that's flagged a payable is truly a payable
        lmd_payables[payable_key(l)] << l if s(l["payable"]) == "Y"
      end
    end

    [brokerage_payables, lmd_payables]
  end


  def create_receivable receivable_lines, brokerage_receivable = false
    first_line = receivable_lines.first

    lmd_receivable = nil
    lmd_receivable_from_brokerage = nil
    if lmd_division?(s(first_line["header division"]))
      lmd_receivable = true
      lmd_receivable_from_brokerage = false
    else
      lmd_receivable_from_brokerage = (!brokerage_receivable && lmd_division?(s(first_line["line division"])))
      lmd_receivable = lmd_receivable_from_brokerage
    end

    # If we're getting this data back, then we should have already requested it, look up 
    # that request.
    export = IntacctAllianceExport.where(file_number: s(first_line['file number']), suffix: suffix(first_line)).first
    return unless export

    # Make sure we haven't already sent data for this receivable, but we will allow recreating receivables that haven't been uploaded
    company = (lmd_receivable ? LMD_COMPANY_CODE : VFI_COMPANY_CODE)
    invoice_number = (lmd_receivable_from_brokerage ? s(first_line["freight file number"]) : s(first_line["invoice number"]))
    customer_number = (lmd_receivable_from_brokerage ? LMD_VFI_CUSTOMER_CODE : find_customer_number(s(first_line["customer"])))

    existing = IntacctReceivable.where(company: company, invoice_number: invoice_number, customer_number: customer_number).first_or_create!
    r = nil
    Lock.with_lock_retry(existing) do
      return unless existing.intacct_upload_date.nil? && existing.intacct_key.nil?

      r = existing
      r.intacct_receivable_lines.destroy_all

      r.intacct_errors = nil
      r.intacct_alliance_export = export
      r.company = company
      r.invoice_number = invoice_number
      r.invoice_date = parse_date first_line["invoice date"]
      r.customer_number = customer_number
      # We're not going to get currency for our Export division, however, we know everything we do there is going to be USD
      currency = s first_line["currency"]
      r.currency = currency.blank? ? "USD" : currency

      actual_charge_sum = BigDecimal.new 0

      receivable_lines.each do |line|
        # Numeric values are going to come across as Strings because we're getting json posted back to us.
        charge_amount = as_dec line["charge amount"]
        actual_charge_sum += charge_amount

        rl = r.intacct_receivable_lines.build
        # If we're generating a brokerage receivable, the line item locations we create should always be for the 
        # originating division.  This is because some lines on a brokerage file may be flagged as LMD lines and linked
        # to the LMD division.  This is great for behind the scenes tracking, but in reality the entirety of the brokerage
        # receivable should be against the broker division.
        rl.location = lmd_receivable_from_brokerage ? s(line["line division"]) : s(line["header division"])

        rl.amount = charge_amount
        rl.charge_code = s line["charge code"]
        rl.charge_description = s line["charge description"]
        # If this is a true LMD receivable, there's not going to be a broker file # (even if the query returns one, it's invalid)
        rl.broker_file = (lmd_receivable && !lmd_receivable_from_brokerage) ? nil : s(line["broker file number"])
        rl.freight_file = s line["freight file number"]
        rl.line_of_business = (lmd_receivable ? "Freight" : "Brokerage")
        rl.vendor_number = find_vendor_number(s(line["vendor"]))
        rl.vendor_reference = s(line["vendor reference"])
      end

      # Credit Memo or Sales Order Invoice (depends on the sum of the charges)
      # Sales Order Invoice is for all standard invoices
      # Credit Memo is for cases where we're backing out charges from a previous Sales Order Invoice
      if actual_charge_sum >= 0
        r.receivable_type = IntacctReceivable.create_receivable_type r.company, false
      else
        r.receivable_type = IntacctReceivable.create_receivable_type r.company, true
        # Credit Memos should have all credit lines as positive amounts.  The lines come to us
        # as negative amounts from Alliance and the debits as postive amounts so we invert them.
        r.intacct_receivable_lines.each {|l| l.amount = (l.amount * -1)}
      end

      r.save!
      export.data_received_date = Time.zone.now
      export.save!
    end
    
    r
  end

  def create_payable payable_key, payable_lines
    vendor = find_vendor_number(extract_vendor_from_key(payable_key))
    first_line = payable_lines.first

    export = IntacctAllianceExport.where(file_number: s(first_line['file number']), suffix: suffix(first_line)).first
    return unless export

    lmd_company = lmd_division?(s(first_line["header division"])) 
    company = (lmd_company ? LMD_COMPANY_CODE : VFI_COMPANY_CODE) 
    bill_number = s first_line["invoice number"]

    existing = IntacctPayable.where(company: company, vendor_number: vendor, bill_number: bill_number).first_or_create!
    p = nil
    Lock.with_lock_retry(existing) do
      return unless existing.intacct_upload_date.nil? && existing.intacct_key.nil?
      
      payable_to_lmd = (vendor == VFI_LMD_VENDOR_CODE)

      p = existing
      p.intacct_payable_lines.destroy_all

      p.intacct_errors = nil
      p.intacct_alliance_export = export
      p.company = company
      p.vendor_number = vendor
      # Since it's possible we'll have multiple vendor references on file, don't use the header one.
      # We'll never have multiple freight files for payables to lmd division, so we're safe sending theing file number
      # as the reference for it.
      p.vendor_reference = payable_to_lmd ? s(first_line["freight file number"]) : nil
      # We're not going to get currency for our Export division, however, we know everything we do there is going to be USD
      currency = s first_line["currency"]
      p.currency = currency.blank? ? "USD" : currency

      # Use the invoice number as the bill number for payables (which will be unique then per vendor)
      p.bill_number = bill_number
      p.bill_date = parse_date first_line["invoice date"]

      payable_lines.each do |l|
        pl = p.intacct_payable_lines.build

        pl.charge_code = s l["charge code"]
        pl.gl_account = payable_to_lmd ? "2025" : gl_account(pl.charge_code)
        pl.amount = as_dec l["charge amount"]
        description = s l["charge description"]
        # append the vendor reference to the description if there is one since the bill doesn't carry a line level reference
        description += " - #{s(l["vendor reference"])}" unless l["vendor reference"].blank?
        pl.charge_description = description

        # If we're generating a payable to the LMD division from a brokerage file, then we should be using
        # the header division (since we don't want to record LMD as paying itself)
        pl.location = payable_to_lmd ? s(l["header division"]) : s(l["line division"])
        pl.line_of_business = lmd_company ? "Freight" : "Brokerage"
        pl.freight_file = s l["freight file number"]
        pl.customer_number = find_customer_number(s(l["customer"]))

        # If the payable originated under the LMD Company, then we won't have a Broker File #
        pl.broker_file = s(l["broker file number"]) unless lmd_company
        pl.check_number =  no_zero l["check number"]
        bank_number = no_zero l["bank number"]
        pl.bank_number = DataCrossReference.find_alliance_bank_number(bank_number) if bank_number
        pl.check_date = parse_date l["check date"]
        if pl.bank_number
          pl.bank_cash_gl_account = DataCrossReference.find_intacct_bank_gl_cash_account pl.bank_number
        end
      end

      p.save!
      export.data_received_date = Time.zone.now
      export.save!

    end
    
    p
  end

  private 

    def self.format_results r
      # Since we're serializing params as json, if we get a string, decode them
      if r.is_a? String
        ActiveSupport::JSON.decode r
      else
        r
      end
    end

    def payable_key line
      # The key on the payable lines needs to be the Vendor + Check No + Bank No + Check Date
      # (Really, the Check No should suffice but the "real" alliance Primary key are those 3 pieces of info)
      [s(line["vendor"]), s(line["check number"]), s(line["bank number"]), s(line["check date"])].map {|v| v.to_s}.join("~")
    end

    def extract_vendor_from_key key
      key.split("~")[0]
    end

    def parse_date date
      # Alliance dates are just numbers ie. 20140302
      date ? Date.strptime(date.to_s, "%Y%m%d") : nil
    rescue
      nil
    end

    def lmd_division? division
      ["11", "12"].include? division
    end

    def gl_account charge_code
      DataCrossReference.find_alliance_gl_code charge_code
    end

    def no_zero v
      d = as_dec(v)
      d == 0 ? nil : v
    end

    def s v
      v.nil? ? v : v.strip
    end

    def as_dec v
      (v.is_a? BigDecimal) ? v : BigDecimal.new(v.to_s)
    end

    def extract_file_numbers r
      file_numbers = {:broker_file => [], :freight_file => []}
      lines = r.respond_to?(:intacct_receivable_lines) ? r.intacct_receivable_lines : r.intacct_payable_lines
      lines.each do |l|
        file_numbers[:broker_file] << l.broker_file unless l.broker_file.blank?
        file_numbers[:freight_file] << l.freight_file unless l.freight_file.blank?
      end
      file_numbers[:broker_file].uniq!
      file_numbers[:freight_file].uniq!

      file_numbers
    end

    def merge_file_numbers numbers, new_numbers
      numbers[:broker_file] = (numbers[:broker_file] + new_numbers[:broker_file]).uniq
      numbers[:freight_file] = (numbers[:freight_file] + new_numbers[:freight_file]).uniq
      numbers
    end

    def suffix line
      suf = s(line["suffix"])
      suf.blank? ? nil : suf.strip
    end

    def find_customer_number alliance_customer
      # The vast majority of the lookups we do here are going to be for the same value..so just cache it
      @cust_xref ||= {}

      unless @cust_xref.include? alliance_customer
        # If the xref exists use it, otherwise use the original value
        xref = DataCrossReference.find_intacct_customer_number 'Alliance', alliance_customer
        @cust_xref[alliance_customer] = (xref.blank? ? alliance_customer : xref)
      end

      @cust_xref[alliance_customer]
    end

    def find_vendor_number alliance_vendor
      # The vast majority of the lookups we do here are going to be for the same value..so just cache it
      @vend_xref ||= {}

      unless @vend_xref.include? alliance_vendor
        # If the xref exists use it, otherwise use the original value
        xref = DataCrossReference.find_intacct_vendor_number 'Alliance', alliance_vendor
        @vend_xref[alliance_vendor] = (xref.blank? ? alliance_vendor : xref)
      end

      @vend_xref[alliance_vendor]
    end

end; end; end; end