module OpenChain; module CustomHandler; module Intacct; module IntacctBillingParserSupport
  extend ActiveSupport::Concern

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
    destroy_unreferenced_receivables(export, Array.wrap(receivables))
    destroy_unreferenced_payables(export, Array.wrap(payables))

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

  def uploaded_to_intacct? obj
    obj.present? && obj.intacct_upload_date.present?
  end

  def find_existing_payable payables, vendor, bill_number
    return nil unless payables
    payables.find {|p| p.bill_number == bill_number && p.vendor_number == vendor }
  end

  def find_existing_receivable receivables, invoice_number
    return nil unless receivables
    receivables.find {|r| r.invoice_number == invoice_number }
  end

  def parse_date value
    Time.zone.parse(value).to_date
  end

  def parse_decimal value
    value.present? ? BigDecimal(value) : nil
  end

end; end; end; end