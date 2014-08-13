module OpenChain; module CustomHandler; module Intacct; class IntacctInvoiceDetailsParser

  VFI_LMD_VENDOR_CODE ||= "LMD"
  LMD_VFI_CUSTOMER_CODE ||= "VANDE"
  VFI_COMPANY_CODE ||= 'vfc'
  LMD_COMPANY_CODE ||= 'lmd'
  PREPAID_PAYMENTS_GL_ACCOUNT ||= "2021"

  def self.parse_query_results result_set
    self.new.parse(format_results(result_set))
  end

  def self.parse_advance_check_results result_set
    self.new.parse_advance_check_results(format_results(result_set))
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
        merge_file_numbers(lines, extract_file_numbers(p)) if p
      end

      lmd_payables.each_pair do |key, payable_lines|
        p = create_payable key, payable_lines
        merge_file_numbers(lines, extract_file_numbers(p)) if p
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
    customer_number = (lmd_receivable_from_brokerage ? LMD_VFI_CUSTOMER_CODE : find_customer_number(s(first_line["customer"])))

    if lmd_receivable_from_brokerage
      # We need this LMD Identifier for cases where we are updating LMD Invoice information.  The Invoice Number coming across from Alliance
      # is going to be identical for LMD Files on 2 different entries, so the only way we know which one to update is by using both the broker file
      # and the freight file as some sort of identifier
      existing = IntacctReceivable.where(company: company, customer_number: customer_number, lmd_identifier: lmd_identifier(first_line)).first_or_create!
    else
      existing = IntacctReceivable.where(company: company, invoice_number: s(first_line["invoice number"]), customer_number: customer_number).first_or_create!
    end
    
    r = nil
    Lock.with_lock_retry(existing) do
      return unless existing.intacct_upload_date.nil? && existing.intacct_key.nil?

      r = existing
      r.intacct_receivable_lines.destroy_all

      r.intacct_errors = nil
      r.intacct_alliance_export = export
      r.company = company
      # This should only ever actually happen on LMD Receivables made from Brokerage Files
      if r.invoice_number.blank?
        r.invoice_number = lmd_receivable_invoice_number company, customer_number, s(first_line["freight file number"])
      end
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

    # Checks need to be recorded as different types so that we know when creating advanced checks if the number has already been invoiced or not.
    # There's not really much chance of that actually being the case, but we need to be absolutely certain that doesn't happen.
    check_number = no_zero(first_line["check number"])
    payable_type = check_number ? IntacctPayable::PAYABLE_TYPE_CHECK : IntacctPayable::PAYABLE_TYPE_BILL

    existing = nil
    Lock.acquire(Lock::INTACCT_DETAILS_PARSER, times: 3) do
      # Check number needs to be part of the key since it's very possible we'll issue multiple checks to the same vendor on the same invoice
      existing = IntacctPayable.where(company: company, vendor_number: vendor, bill_number: bill_number, payable_type: payable_type, check_number: check_number).first_or_create!
    end
    
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

        # Record the check number at the header to make it easier to lookup for advanced check screening.
        if pl.check_number
          p.check_number = pl.check_number
        end
        bank_number = no_zero l["bank number"]
        pl.bank_number = DataCrossReference.find_alliance_bank_number(bank_number) if bank_number
        pl.check_date = parse_date l["check date"]
        if pl.bank_number
          # The bank cash gl account is actually the account to credit when recording the check - the debit 
          # on invoiced checks is always against the charge code GL expense account.
          # For checks that have been recorded as advanced payments, then we need to actually be crediting the
          # 2021 Prepaid Advanced Payments account, since that is the account the advanced payments debit.
          # Account is used so we know at any point how much money is floating as checks and have not been billed 
          # to a customer.

          if IntacctPayable.where(company: p.company, vendor_number: p.vendor_number, bill_number: p.bill_number, check_number: pl.check_number, payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED).exists?
            pl.bank_cash_gl_account = PREPAID_PAYMENTS_GL_ACCOUNT
          else
            pl.bank_cash_gl_account = DataCrossReference.find_intacct_bank_gl_cash_account pl.bank_number
          end
        end
      end

      p.save!
      export.data_received_date = Time.zone.now
      export.save!

    end
    
    p
  end

  def parse_advance_check_results result_set
    # In theory, according to Luca, each line should be a different check...in practice, I'm not sure that's true.
    # Split out the values that are the same invoice # and check number into distinct groups
    checks = {}
    result_set.each do |line|
      key = payable_key line
      checks[key] ||= []
      checks[key] << line
    end

    checks.values.each do |check_lines|
      create_advance_check_payable check_lines
    end

  end

  def create_advance_check_payable lines
    first_line = lines.first

    # We first need to confirm that we don't already have an open payable already in the system for this line.
    lmd_company = lmd_division?(s(first_line["header division"])) 
    company = (lmd_company ? LMD_COMPANY_CODE : VFI_COMPANY_CODE)
    vendor = find_vendor_number s(first_line['vendor'])
    check_number = s(first_line['check number'])
    bill_number = s(first_line['invoice number'])

    # We shouldn't create an advanced payment if there is a check payable (.ie the file is invoiced already)
    p = nil
    Lock.acquire(Lock::INTACCT_DETAILS_PARSER, times: 3) do
      return if IntacctPayable.where(company: company, vendor_number: vendor, bill_number: bill_number, check_number: check_number, payable_type: IntacctPayable::PAYABLE_TYPE_CHECK).exists?

      p = IntacctPayable.where(company: company, vendor_number: vendor, bill_number: bill_number, check_number: check_number, payable_type: IntacctPayable::PAYABLE_TYPE_ADVANCED).first_or_create!
    end

    return unless p
    
    Lock.with_lock_retry(p) do 
      return unless p.intacct_key.blank? && p.intacct_upload_date.nil?

      # Blank any existing lines...
      p.intacct_payable_lines.destroy_all

      p.intacct_errors = nil
      p.vendor_reference = s first_line["vendor reference"]
      p.currency = s first_line["currency"]
      # Because the invoice hasn't been finalized, there is no invoice date associated w/ the bill yet.
      p.bill_date = parse_date first_line["check date"]

      lines.each do |l|
        pl = p.intacct_payable_lines.build

        pl.charge_code = s l["charge code"]
        # The GL account (.ie the account to debit) is always the prepaid payments GL account.
        # When the invoice is finally billed, the check line will come through on that and zero this balance out.
        pl.gl_account = PREPAID_PAYMENTS_GL_ACCOUNT
        pl.amount = as_dec l["charge amount"]
        description = s l["charge description"]
        # append the vendor reference to the description if there is one since the bill doesn't carry a line level reference
        description += " - #{s(l["vendor reference"])}" unless l["vendor reference"].blank?
        pl.charge_description = description
        pl.location = s(l["header division"])
        pl.line_of_business = lmd_company ? "Freight" : "Brokerage"
        pl.freight_file = s l["freight file number"]
        pl.customer_number = find_customer_number(s(l["customer"]))

        # If the payable originated under the LMD Company, then we won't have a Broker File #
        pl.broker_file = s(l["broker file number"]) unless lmd_company
        pl.check_number =  no_zero l["check number"]

        # Record the check number at the header so that we can easily identify it both for updates and when parsing invoice data
        # to look for advanced checks (see #create_payable above)
        if pl.check_number
          p.check_number = pl.check_number
        end

        bank_number = no_zero l["bank number"]
        pl.bank_number = DataCrossReference.find_alliance_bank_number(bank_number) if bank_number
        pl.check_date = parse_date l["check date"]
        if pl.bank_number
          pl.bank_cash_gl_account = DataCrossReference.find_intacct_bank_gl_cash_account pl.bank_number
        end
      end

      p.save!
    end

    # Send up all the referenced broker and freight file dimensions
    broker_files = p.intacct_payable_lines.map(&:broker_file).uniq.compact
    broker_files.each do |bf|
      OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Broker File", bf, bf)
    end

    freight_files = p.intacct_payable_lines.map(&:freight_file).uniq.compact
    freight_files.each do |ff|
      OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Freight File", ff, ff)
    end
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
      # All of checknumber, bank number, check date must be non-zero before we should use them as part of the key.
      # For some reason, Alliance has check dates for some lines that aren't actually checks..argh...
      key = [s(line["vendor"]), s(line["check number"]), s(line["bank number"]), s(line["check date"])]

      if key.reject {|v| v.nil? || v == "0"}.size < 4
        key = [s(line["vendor"]), "0", "0", "0"]
      end

      key.map {|v| v.to_s}.join("~")
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

    def lmd_identifier line
      s(line["broker file number"]) + "~" + s(line["freight file number"])
    end

    def lmd_receivable_invoice_number company, customer_number, freight_file_number
      existing_invoice_count = IntacctReceivable.where(company: company, customer_number: customer_number).where("invoice_number REGEXP ?", "#{freight_file_number}[A-Z]*").count
      freight_file_number + get_suffix(existing_invoice_count)
    end

    def get_suffix count
      suffix = ""
      if count > 0
        first_number = (count / 27).to_i
        second_number = (count - (26 * first_number))

        # 64 below represents ASCII # directly prior to ASCII A.
        if first_number > 0
          suffix += (64 + first_number).chr
        end

        if second_number > 0
          suffix += (64 + second_number).chr
        end
      end

      suffix
    end

end; end; end; end