module OpenChain; module CustomHandler; module Masterbrand; class MasterbrandInvoiceGenerator
    
  ENTRY_UNIT_PRICE = 2.50
  ENTRY_LIMIT = 250
  MONTHLY_UNIT_PRICE = 1000.00

  def self.run_schedulable
    ActiveRecord::Base.transaction do
      billables = get_new_billables
      inv = create_invoice
      bill_new_entries(billables, inv)
      bill_monthly_charge inv
    end
  end

  def self.create_invoice
    co = Company.where(master: true).first
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def self.bill_monthly_charge invoice
    invoice.vfi_invoice_lines.create! vfi_invoice: invoice, quantity: 1, unit: "ea", unit_price: MONTHLY_UNIT_PRICE, charge_description: "monthly charge"
  end

  def self.get_new_billables
    BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"')
                 .joins('INNER JOIN entries e ON billable_events.billable_eventable_type = "Entry" and billable_events.billable_eventable_id = e.id')
                 .where('ie.id IS NULL')
                 .where('billable_events.event_type = "entry_new"')
                 .where('e.file_logged_date >= "2016-05-01" OR e.file_logged_date IS NULL')
  end

  def self.bill_new_entries billables, invoice
    qty_to_bill = billables.count - ENTRY_LIMIT
    if qty_to_bill > 0
      line = invoice.vfi_invoice_lines.create! quantity: qty_to_bill, unit: "ea", unit_price: ENTRY_UNIT_PRICE, charge_description: "new entry exceeding #{ENTRY_LIMIT}/mo. limit"
      write_invoiced_events billables, line
    end
  end

  def self.write_invoiced_events billables, invoice_line
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'MasterbrandInvoiceGenerator', charge_type: 'unified_entry_line')
      end
    end
  end

end; end; end; end