module OpenChain; module CustomHandler; module Masterbrand; class MasterbrandInvoiceGenerator

  ENTRY_UNIT_PRICE = 2.50
  ENTRY_LIMIT = 250
  MONTHLY_UNIT_PRICE = 1000.00

  def self.run_schedulable
    ActiveRecord::Base.transaction do
      inv = create_invoice
      bill_monthly_charge(get_new_billables(ENTRY_LIMIT),inv)
      bill_new_entries(get_new_billables, inv)
    end
  end

  def self.create_invoice
    co = Company.where(master: true).first
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def self.bill_monthly_charge billables, invoice
    line = invoice.vfi_invoice_lines.create! vfi_invoice: invoice, quantity: 1, unit: "ea", unit_price: MONTHLY_UNIT_PRICE, charge_description: "Monthly charge for up to #{ENTRY_LIMIT} entries"
    write_invoiced_events billables, line
  end

  def self.get_new_billables limit=nil
    be = BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"')
                 .joins('INNER JOIN entries e ON billable_events.billable_eventable_type = "Entry" and billable_events.billable_eventable_id = e.id')
                 .where('ie.id IS NULL')
                 .where('billable_events.event_type = "entry_new"')
                 .where('e.file_logged_date >= "2016-05-01" OR e.file_logged_date IS NULL')
    be = be.limit(limit) if limit
    be
  end

  def self.bill_new_entries billables, invoice
    return if billables.empty?
    line = invoice.vfi_invoice_lines.create! quantity: billables.length, unit: "ea", unit_price: ENTRY_UNIT_PRICE, charge_description: "Unified Entry Audit; Up To #{ENTRY_LIMIT} Entries"
    write_invoiced_events billables, line
  end

  def self.write_invoiced_events billables, invoice_line
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'MasterbrandInvoiceGenerator', charge_type: 'unified_entry_line')
      end
    end
  end

end; end; end; end
