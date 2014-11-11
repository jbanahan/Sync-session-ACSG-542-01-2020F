module OpenChain; module CustomHandler; module Intacct; class IntacctInvoiceDetailsParser
  include ActionView::Helpers::NumberHelper

  VFI_LMD_VENDOR_CODE ||= "LMD"
  LMD_VFI_CUSTOMER_CODE ||= "VANDE"
  VFI_COMPANY_CODE ||= 'vfc'
  LMD_COMPANY_CODE ||= 'lmd'
  PREPAID_PAYMENTS_GL_ACCOUNT ||= "2021"

  def self.parse_query_results result_set
    self.new.parse(format_results(result_set))
  end

  def self.parse_check_result result_set
    self.new.parse_check_result(format_results(result_set))
  end

  def parse result_set
    # The value we're receiving here is a hash exactly like you'd get back from a raw SQL connection query execution
    # Be aware that the way Alliance stores and returns most string values includes a bunch of trailing spaces
    # Also, every value in the result set (dates and numbers) are strings.

    # If we're getting this data, then we should have already requested it, look up the export 
    # based on that request.
    export = find_alliance_export_record result_set
    return unless export

    brokerage_receivable, lmd_receivable = extract_receivable_lines export, result_set

    # The payables are hashes hashed by vendor number and vendor reference
    brokerage_payable_lines, lmd_payable_lines = extract_payable_lines export, result_set

    Lock.with_lock_retry(export) do
      # Intacct requires that the broker file and freight file dimensions are in the system prior to 
      # uploading the payable/receivable information.  So we're tracking the numbers referenced in the 
      # result set and will upload them immediately.

      lines = {:broker_file => [], :freight_file => []}
      br = create_receivable(export, brokerage_receivable, true) unless brokerage_receivable.empty?
      merge_file_numbers(lines, extract_file_numbers(br)) if br

      lr = create_receivable(export, lmd_receivable) unless lmd_receivable.empty?
      merge_file_numbers(lines, extract_file_numbers(lr)) if lr


      brokerage_payables = []
      brokerage_payable_lines.each_pair do |key, payable_lines|
        p = create_payable export, key, payable_lines
        if p
          brokerage_payables << p
          merge_file_numbers(lines, extract_file_numbers(p))
        end
      end

      lmd_payables = []
      lmd_payable_lines.each_pair do |key, payable_lines|
        p = create_payable export, key, payable_lines
        if p
          lmd_payables << p
          merge_file_numbers(lines, extract_file_numbers(p))
        end
      end

      lines[:broker_file].each do |bf|
        OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Broker File", bf, bf)
      end

      lines[:freight_file].each do |ff|
        OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Freight File", ff, ff)
      end

      receivables_valid = validate_ar_values export, br, lr
      payables_valid = validate_ap_values export, brokerage_payables, lmd_payables

      # Ensure that nothing gets uploaded for this file if any receivables or payables are bad.
      if receivables_valid
        if !payables_valid
          [br, lr].compact.each do |r|
            r.intacct_errors = "Errors were found in corresponding payables for this file.  Please address those errors before clearing this receivable."
            r.save!
          end
        end
      else
        # Receivables not valid - only bother w/ setting errors if the payables are valid, since we don't want to overwrite the
        # payable errors that might be there.
        if payables_valid
          (brokerage_payables + lmd_payables).each do |p|
            p.intacct_errors = "Errors were found in corresponding receivables for this file.  Please address those errors before clearing this payable."
            p.save!
          end
        end
      end

      export.data_received_date = Time.zone.now
      export.save!
    end
    nil
  end

  def extract_receivable_lines export, result_set
    lmd_receivable = []
    brokerage_receivable = []

    result_set.each do |l|
      if lmd_division?(s(export.division))
        lmd_receivable << l if l["print"] == "Y"
      else
        # A brokerage receivable line is any line that has a Print value of "Y"
        brokerage_receivable << l if l["print"] == "Y"

        # Any line on a brokerage invoice that has a line division of 11 or 12
        # is a receivable, as these represent the "pay through" process where our VFC company
        # pays the LMD company for the portion of the business they did on this file
        lmd_receivable << l if lmd_division?(s(l["line division"])) && !s(l["freight file number"]).blank?
      end
    end

    [brokerage_receivable, lmd_receivable]
  end

  def extract_payable_lines export, result_set
    # using a hash here to easily associate payables w/ a single vendor
    lmd_payables = Hash.new {|h, k| h[k] = []}
    brokerage_payables = Hash.new {|h, k| h[k] = []}

    result_set.each do |l|
      broker_invoice = !lmd_division?(s(export.division))

      vendor = find_vendor_number s(l["vendor"]), s(l["pay type"])
      # A brokerage payable is any brokerage invoice line that has a vendor
      if broker_invoice 
        # Any line marked a payable is actually a payable
        if l["payable"] == "Y"
          brokerage_payables[vendor] << l
        elsif lmd_division?(s(l["line division"])) && !s(l["freight file number"]).blank?
          # If the division on the line is 11 or 12, then the line becomes a payable to the LMD division from 
          # the brokerage division (essentially the inverse of the LMD receivable lines)
          brokerage_payables[VFI_LMD_VENDOR_CODE] << l
        end
      else
        # If this is an lmd invoice, then every line that's flagged a payable is truly a payable
        lmd_payables[vendor] << l if s(l["payable"]) == "Y"
      end
    end

    [brokerage_payables, lmd_payables]
  end


  def create_receivable export, receivable_lines, brokerage_receivable = false
    first_line = receivable_lines.first

    lmd_receivable = nil
    lmd_receivable_from_brokerage = nil
    if lmd_division?(s(export.division))
      lmd_receivable = true
      lmd_receivable_from_brokerage = false
    else
      lmd_receivable_from_brokerage = (!brokerage_receivable && lmd_division?(s(first_line["line division"])))
      lmd_receivable = lmd_receivable_from_brokerage
    end

    company = (lmd_receivable ? LMD_COMPANY_CODE : VFI_COMPANY_CODE)
    customer_number = (lmd_receivable_from_brokerage ? LMD_VFI_CUSTOMER_CODE : find_customer_number(s(export.customer_number)))

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
      # Make sure we haven't already sent data for this receivable, but we will allow recreating receivables that haven't been uploaded
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

      r.invoice_date = export.invoice_date
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
        rl.location = lmd_receivable_from_brokerage ? s(line["line division"]) : s(export.division)

        rl.amount = charge_amount
        rl.charge_code = s line["charge code"]
        rl.charge_description = s line["charge description"]
        # If this is a true LMD receivable, there's not going to be a broker file # (even if the query returns one, it's invalid)
        rl.broker_file = (lmd_receivable && !lmd_receivable_from_brokerage) ? nil : s(line["broker file number"])
        rl.freight_file = s line["freight file number"]
        rl.line_of_business = (lmd_receivable ? "Freight" : "Brokerage")
        rl.vendor_number = find_vendor_number(s(line["vendor"]), s(line["pay type"]))
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
    end
    
    r
  end

  def create_payable export, vendor, payable_lines
    first_line = payable_lines.first

    header_division = export.division
    lmd_company = lmd_division?(header_division) 
    company = (lmd_company ? LMD_COMPANY_CODE : VFI_COMPANY_CODE) 
    # Use the invoice number as the bill number for payables (which will be unique then per vendor)
    bill_number = s first_line["invoice number"]

    # We don't need to bother ourselves w/ checks any longer here, what we will do is look into the check file as we're uploading the data
    # and add invoice adjustments to the payable to back out payments from check lines on the same payable.
    existing = nil
    Lock.acquire(Lock::INTACCT_DETAILS_PARSER, times: 3) do
      # Check number needs to be part of the key since it's very possible we'll issue multiple checks to the same vendor on the same invoice
      existing = IntacctPayable.where(company: company, vendor_number: vendor, bill_number: bill_number, payable_type: IntacctPayable::PAYABLE_TYPE_BILL).first_or_create!
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

      p.bill_number = bill_number
      p.bill_date = export.invoice_date

      payable_lines.each do |l|
        pl = p.intacct_payable_lines.build

        pl.charge_code = s l["charge code"]
        pl.gl_account = payable_to_lmd ? "6085" : gl_account(pl.charge_code)
        pl.amount = as_dec l["charge amount"]
        description = s l["charge description"]
        # append the vendor reference to the description if there is one since the bill doesn't carry a line level reference
        description += " - #{s(l["vendor reference"])}" unless l["vendor reference"].blank?
        pl.charge_description = description

        # If we're generating a payable to the LMD division from a brokerage file, then we should be using
        # the header division (since we don't want to record LMD as paying itself)
        pl.location = payable_to_lmd ? s(header_division) : s(l["line division"])
        pl.line_of_business = lmd_company ? "Freight" : "Brokerage"
        pl.freight_file = s l["freight file number"]
        pl.customer_number = find_customer_number(s(export.customer_number))

        # If the payable originated under the LMD Company, then we won't have a Broker File #
        pl.broker_file = s(l["broker file number"]) unless lmd_company
        pl.check_number =  no_zero l["check number"]
        bank_number = no_zero l["bank number"]
        pl.bank_number = DataCrossReference.find_alliance_bank_number(bank_number) if bank_number
        pl.check_date = parse_date l["check date"]
      end

      p.save!
    end
    
    p
  end

  def parse_check_result result_set
    # All we're really doing here is pulling a few additional pieces of information about the check that 
    # couldn't be retrieved from the check register report that Alliance publishes

    # There should only be a single query result line and the check record and export should already exist
    first_line = result_set.first

    export = nil
    Lock.acquire(Lock::INTACCT_DETAILS_PARSER, times: 3) do
      # The result data doesn't include the file suffix, since that's not associated w/ the check in the AP File table (for some reason)
      export = IntacctAllianceExport.where(file_number: s(first_line['file number']), check_number: s(first_line['check number']), export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK).first
    end

    if export
      check = nil
      Lock.with_lock_retry(export) do
        # At this point in time, we only ever have a single check per data export object
        check = export.intacct_checks.first 

        # Just a really basic check to verify we're dealing w/ the right export object
        if check && check.check_number == s(first_line['check number']) && check.intacct_upload_date.nil? && check.intacct_key.nil?
          check.intacct_errors = nil

          # Really all we need here is to set the company, the division and the Line of Business
          # and then adjust the customer and vendor numbers to use the xref'ed values.
          check.customer_number = find_customer_number(check.customer_number)
          check.vendor_number = find_vendor_number(check.vendor_number, s(first_line["pay type"]))

          check.location = first_line["division"]
          lmd_company = lmd_division?(check.location)
          if lmd_company
            check.line_of_business = "Freight"
            check.company = LMD_COMPANY_CODE
          else
            check.line_of_business = 'Brokerage'
            check.company = VFI_COMPANY_CODE
            check.broker_file = first_line['file number']
          end
          check.freight_file = first_line['freight file']
          check.currency = first_line['currency'].blank? ? 'USD' : first_line['currency']

          check.save!
          export.division = first_line["division"]
          export.data_received_date = Time.zone.now
          export.save!
        end
      end

      if check
        if check.company == LMD_COMPANY_CODE
          OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Freight File", check.freight_file, check.freight_file)
        else
          OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Broker File", check.broker_file, check.broker_file) 
          OpenChain::CustomHandler::Intacct::IntacctClient.delay.async_send_dimension("Freight File", check.freight_file, check.freight_file) if check.freight_file && !check.freight_file.empty?
        end
      end
    end
  end

  private

    def validate_ar_values export, brokerage_receivable, lmd_receivable
      # Since the data for this process comes from a day end Alliance report, we know how much our receivables
      # should total to.  Verify this amount, and if it's not correct...error them all.

      # If the export was originally for the LMD division (.ie not a freight passthrough)
      # then we just need to sum the LMD receivables.
      receivable = lmd_division?(export.division) ? lmd_receivable : brokerage_receivable
      
      # Credit notes should be summed as negative amounts (they're in intacct as positve amounts)
      sum = BigDecimal.new "0"

      # It's possible we don't get any receivable lines, so don't fail if that happens
      if receivable
        multiplier = (receivable.receivable_type =~ /#{IntacctReceivable::CREDIT_INVOICE_TYPE}/i) ? -1 : 1
        sum = receivable.intacct_receivable_lines.inject(BigDecimal.new("0")) {|total, l| total + (l.amount * multiplier)}
      end
      
      valid = true
      if export.ar_total != sum
        valid = false
        [brokerage_receivable, lmd_receivable].compact.each do |r|
          r.intacct_errors = "Expected an AR Total of #{number_to_currency(export.ar_total)}.  Received from Alliance: #{number_to_currency(sum)}."
          r.save!
        end
      end

      valid
    end

    def validate_ap_values export, brokerage_payables, lmd_payables
      # Since the data for this process comes from a day end Alliance report, we know how much our payables
      # should total to.  Verify this amount, and if it's not correct...error them all.

      # If the export was originally for the LMD division (.ie not a freight passthrough)
      # then we just need to sum the LMD payables.

      # NOTE: Payables to LMD are NOT reported by the Alliance Day End reporting process, so exclude these from our
      # validations.
      payables = []
      if lmd_division?(export.division)
        payables = lmd_payables
      else
        brokerage_payables.each do |p|
          payables << p unless p.vendor_number == VFI_LMD_VENDOR_CODE
        end
      end

      sum = BigDecimal.new "0"
      payables.each do |p|
        sum = p.intacct_payable_lines.inject(sum) {|total, l| total + l.amount}
      end

      valid = true
      if export.ap_total != sum
        valid = false
        # Make sure all the payables passed in here are errored, so that nothing from the file is uploaded.
        (brokerage_payables + lmd_payables).each do |p|
          p.intacct_errors = "Expected an AP Total of #{number_to_currency(export.ap_total)}.  Received from Alliance: #{number_to_currency(sum)}."
          p.save!
        end
      end

      valid
    end

    def self.format_results r
      # Since we're serializing params as json, if we get a string, decode them
      if r.is_a? String
        ActiveSupport::JSON.decode r
      else
        r
      end
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

    def find_vendor_number alliance_vendor, pay_type
      # The vast majority of the lookups we do here are going to be for the same value..so just cache it
      @vend_xref ||= {}

      unless @vend_xref.include? alliance_vendor
        # If the xref exists use it, otherwise use the original value
        xref = DataCrossReference.find_intacct_vendor_number 'Alliance', alliance_vendor
        @vend_xref[alliance_vendor] = (xref.blank? ? alliance_vendor : xref)
      end

      vendor = @vend_xref[alliance_vendor]

      # We're splitting Customs duty vendor into two different buckets.  One for daily
      # vendor payments and another for the periodic payments.
      # VU161 = Daily Statements
      # VU160 = Periodic

      # If pay type is not present, don't translate...we may have non-import data here and pay type
      # comes from the import entry data
      if vendor.upcase == "VU160" && !pay_type.blank? && pay_type != "6"
        vendor = "VU161"
      end

      vendor
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

    def find_alliance_export_record result_set
      # Since all the data in the query comes from a single export, find the export associated w/ the first line
      first_line = result_set.first

      IntacctAllianceExport.where(file_number: s(first_line['file number']), suffix: suffix(first_line), export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE).first
    end

end; end; end; end