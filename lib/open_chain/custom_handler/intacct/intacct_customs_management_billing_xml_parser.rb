require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/nokogiri_xml_helper'

module OpenChain; module CustomHandler; module Intacct; class IntacctCustomsManagementBillingXmlParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::NokogiriXmlHelper

  VFI_COMPANY_CODE ||= 'vfc'.freeze

  def self.parse data, _opts = {}
    self.new.parse xml_document(data)
  end

  def parse document
    root = document.root
    file_number = et(root, "fileNo")
    suffix = et(root, "suffix") || nil
    inbound_file.add_identifier(:invoice_number, compose_invoice_number(file_number, suffix))
    inbound_file.add_identifier(:broker_reference, file_number)

    prepared = et(root, "invoicePrepared")
    suppressed = et(root, "invoiceSuppressed")
    if prepared != "Y"
      inbound_file.add_warning_message("Invoice has not been marked as prepared.")
      return
    elsif suppressed == "Y"
      inbound_file.add_warning_message("Invoice has been marked as suppressed.")
      return
    end

    finalized_export = find_intacct_export(file_number, suffix) do |export|
      populate_export(root, export)
      receivables = populate_receivables(root, export)
      payables = populate_payables(root, export)
      finalize_export(export, receivables, payables)

      export.save!
      export
    end

    OpenChain::CustomHandler::Intacct::IntacctDataPusher.delay.push_billing_export_data(finalized_export.id) if finalized_export.present?

    nil
  end

  private

    def find_intacct_export file_number, suffix
      export = nil
      Lock.acquire("IntacctAllianceExport-#{file_number}#{suffix}") do
        export = IntacctAllianceExport.where(file_number: file_number, suffix: suffix, export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE)
                                      .first_or_create!(data_requested_date: Time.zone.now)
      end

      e = nil
      Lock.db_lock(export) do
        e = yield export
      end

      e
    end

    def finalize_export export, receivables, payables
      export.data_received_date = Time.zone.now
      ar_total = BigDecimal("0")
      ap_total = BigDecimal("0")

      Array.wrap(receivables).each do |ir|
        ir.intacct_receivable_lines.each do |rl|
          amount = rl.amount
          # Credit invoice amounts are (at this point) positive
          # values. We want the credits to negatively affect AR
          # (.ie if we're crediting an account $-50 the total AR amount should debit by $-50,
          #  but at this point the amounts in the receivable is postive - because that's
          # how accounting packages handle this)
          amount = (amount * -1) if IntacctReceivable.credit_invoice?(ir)

          ar_total += amount
        end
      end

      Array.wrap(payables).each do |ip|
        ip.intacct_payable_lines.each do |pl|
          ap_total += pl.amount
        end
      end

      export.ar_total = ar_total
      export.ap_total = ap_total

      destroy_unreferenced_receivables(export, receivables)
      destroy_unreferenced_payables(export, payables)

      nil
    end

    def destroy_unreferenced_receivables export, referenced_receivables
      export.intacct_receivables.each do |r|
        receivable = find_existing_receivable(referenced_receivables, r.invoice_number)
        # If we couldn't find the receivable in the list of ones we just built...delete it.
        # UNLESS it's already been pushed to intacct.  Then we should leave it.
        r.destroy! if receivable.nil? && !uploaded_to_intacct?(r)
      end
    end

    def destroy_unreferenced_payables export, referenced_payables
      export.intacct_payables.each do |p|
        payable = find_existing_payable(referenced_payables, p.vendor_number, p.bill_number)
        # If we couldn't find the payable in the list of ones we just built...delete it.
        # UNLESS it's already been pushed to intacct.  Then we should leave it.
        p.destroy if payable.nil? && !uploaded_to_intacct?(p)
      end
    end

    def populate_export xml, export
      export.division = et(xml, "divisionNo")
      export.customer_number = customer_number(et(xml, "billToCust"))
      export.invoice_date = parse_date(et(xml, "dateInvoice"))
      nil
    end

    def populate_receivables xml, export
      # There should only ever be a single receivable for these files
      process_ar_lines(xml) do |lines|
        # We'll use the export's invoice number / suffix as the receivable's invoice_number
        invoice_number = compose_invoice_number(export.file_number, export.suffix)
        receivable = find_existing_receivable(export.intacct_receivables, invoice_number)
        if uploaded_to_intacct?(receivable)
          inbound_file.add_warning_message "Receivable #{invoice_number} has already been sent to Intacct."
          break
        end

        if receivable.nil?
          receivable = export.intacct_receivables.create! invoice_number: invoice_number
        else
          receivable.intacct_receivable_lines.destroy_all
        end

        process_receivable(xml, lines, export, receivable)
      end
    end

    def compose_invoice_number file_number, suffix
      suffix.blank? ? file_number : "#{file_number}#{suffix}"
    end

    def parse_date value
      Time.zone.parse(value).to_date
    end

    def process_receivable xml, lines, export, receivable
      # If for some reason we're reprocessing a billing file, we can clear any intacct errors that were already there.
      receivable.intacct_errors = nil
      receivable.company = company_code(xml)
      receivable.invoice_date = export.invoice_date
      receivable.customer_number = export.customer_number

      first_line = lines.first
      receivable.currency = currency(xml, first_line)

      actual_charge_sum = BigDecimal("0")
      lines.each do |line|
        rl = receivable.intacct_receivable_lines.build

        rl.amount = BigDecimal(et(line, "chargeAmtAmt"))
        actual_charge_sum += rl.amount if rl.amount
        rl.location = export.division
        rl.charge_code = charge_code(line)
        rl.charge_description = et(line, "chargeDesc")
        rl.broker_file = export.file_number
        rl.line_of_business = "Brokerage"
        rl.vendor_number = vendor_number(et(line, "vendor"))
        rl.vendor_reference = et(line, "vendorReferenceNo")
      end

      if actual_charge_sum >= 0
        receivable.receivable_type = IntacctReceivable.create_receivable_type receivable.company, false
      else
        receivable.receivable_type = IntacctReceivable.create_receivable_type receivable.company, true
        # Credit Memos should have all credit lines as positive amounts.  The lines come to us
        # as negative amounts from Alliance and the debits as postive amounts so we invert them.
        receivable.intacct_receivable_lines.each { |l| l.amount = (l.amount * -1) }
      end

      receivable.save!
      receivable
    end

    def populate_payables xml, export
      process_ap_lines(xml) do |vendor, lines|
        # We'll use the export's invoice number / suffix as the payables's bill number
        # We're creating a single payable per vendor that appears on the invoice
        bill_number = compose_invoice_number(export.file_number, export.suffix)
        payable = find_existing_payable(export.intacct_payables, vendor, bill_number)
        if uploaded_to_intacct?(payable)
          inbound_file.add_warning_message "Payable #{bill_number} to Vendor #{vendor} has already been sent to Intacct."
          next
        end

        if payable.nil?
          payable = export.intacct_payables.create! vendor_number: vendor, bill_number: bill_number, payable_type: IntacctPayable::PAYABLE_TYPE_BILL
        else
          payable.intacct_payable_lines.destroy_all
        end

        process_payable(xml, lines, export, payable)
      end
    end

    def process_payable xml, lines, export, payable
      # If for some reason we're reprocessing a billing file, we can clear any intacct errors that were already there.
      payable.intacct_errors = nil
      payable.bill_date = export.invoice_date
      payable.company = company_code(xml)
      first_line = lines.first
      payable.currency = currency(nil, first_line)

      # Record the vendor reference as the first non-blank one we find
      vendor_reference = nil
      lines.each do |line|
        pl = payable.intacct_payable_lines.build

        pl.charge_code = charge_code(line)
        pl.gl_account = gl_account(pl.charge_code)
        pl.amount = BigDecimal(et(line, "chargeAmtAmt"))

        charge_description = et(line, "chargeDesc")
        # append the vendor reference to the description if there is one since the bill in intacct doesn't carry a line level reference
        line_reference = et(line, "vendorReferenceNo")
        charge_description += " - #{line_reference}" if line_reference.present?
        pl.charge_description = charge_description

        pl.location = export.division
        pl.line_of_business = "Brokerage"
        pl.customer_number = export.customer_number
        pl.broker_file = export.file_number

        vendor_reference = line_reference if vendor_reference.blank?
      end

      payable.vendor_reference = vendor_reference
      payable.save!
      payable
    end

    def process_ap_lines xml
      # Any line that is listed as being an AP charge needs to be added to a payable.
      payable_lines = {}

      invoice_lines(xml) do |line|
        next unless et(line, "Charge/apY") == "Y"
        next if offsetting_charge_present?(xml, line)

        vendor = vendor_number(et(line, "vendor"))
        payable_lines[vendor] ||= []
        payable_lines[vendor] << line
      end

      payables = []
      payable_lines.each_pair do |vendor, lines|
        payable = yield vendor, lines
        payables << payable if payable
      end
      payables
    end

    def process_ar_lines xml
      lines = []

      invoice_lines(xml) do |line|
        # The printY field seems to indicate if the charge should show on an AR invoice or not
        next unless et(line, "printY") == "Y"
        next if offsetting_charge_present?(xml, line)
        lines << line

      end

      receivable = yield lines if lines.length > 0
      # Even though we should only yield a single receivable here, I'm writing it
      # as though there could be multiple and the rest of the class will also handle
      # it as though it's possible to have multiple receivables.
      receivable.nil? ? [] : [receivable]
    end

    def invoice_lines xml
      xpath(xml, "InvoiceLinesList/InvoiceLines") do |line|
        next if et(line, "suppressAccounting") == "Y"

        yield line
      end
    end

    def uploaded_to_intacct? obj
      obj.present? && obj.intacct_upload_date.present?
    end

    def customer_number cust_no
      @cust_xref ||= Hash.new do |h, k|
        xref = DataCrossReference.find_intacct_customer_number 'Alliance', k
        h[k] = xref.presence || k
      end

      @cust_xref[cust_no]
    end

    def vendor_number vendor
      @vendor_xref ||= Hash.new do |h, k|
        xref = DataCrossReference.find_intacct_vendor_number 'Alliance', k
        h[k] = xref.presence || k
      end

      @vendor_xref[vendor]
    end

    def gl_account charge_code
      @account ||= Hash.new do |h, k|
        h[k] = DataCrossReference.find_alliance_gl_code k
      end

      @account[charge_code]
    end

    def currency xml, line
      cur = et(xml, "currency") unless xml.nil?
      cur = et(line, "currency") if cur.blank?
      cur = "USD" if cur.blank?

      cur
    end

    def company_code xml
      company_number = et(xml, "companyNo")

      # If we add another company to the system, we need to ensure
      # that we handle it...Intacct will fail the upload if the company code
      # is missing, so at least if something like that slips in we can block
      # uploads until we have it set up ready to accept another company's data
      code = nil
      if company_number == "1"
        code = VFI_COMPANY_CODE
      end

      code
    end

    def charge_code line
      charge = et(line, "charge")
      charge.to_s.rjust(4, "0")
    end

    # This is somethign of a strange situation.  The data from CMUS may indicate that
    # an invoice line is not suppressed, but we MAY still not want to include it on
    # receivables and payables if there is another offsetting charge on the invoice.
    #
    # The canonical example is Duty / Duty Paid Direct.  When a Duty Paid Direct line
    # appears on the the invoice and there's also a Duty line on it, then the Duty
    # line should NOT be included in Receivables / Payables.  The Duty line
    # is appearing on the invoice solely for informational purpose.
    def offsetting_charge_present? xml, line
      charge_code = et(line, "charge")
      offset_code_pair = offsetting_charge_codes[charge_code]
      return false if offset_code_pair.blank?

      # So, we're dealing with a code at this point that we know may potentially get
      # suppressed due to a secondary invoice line present on the invoice that cancels
      # it out.  We need to now check if that other code is present on the invoice.
      Array.wrap(offset_code_pair).each do |offset_code|
        return true if xpath(xml, "InvoiceLinesList/InvoiceLines[charge = '#{offset_code}']/charge").present?
      end

      false
    end

    def offsetting_charge_codes
      {"1" => "99"}
    end

    def find_existing_payable payables, vendor, bill_number
      return nil unless payables
      payables.find {|p| p.bill_number == bill_number && p.vendor_number == vendor }
    end

    def find_existing_receivable receivables, invoice_number
      return nil unless receivables
      receivables.find {|r| r.invoice_number == invoice_number }
    end

end; end; end; end