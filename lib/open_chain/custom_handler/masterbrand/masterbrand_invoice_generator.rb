module OpenChain; module CustomHandler; module Masterbrand; class MasterbrandInvoiceGenerator
    
  def self.run_schedulable
    ActiveRecord::Base.transaction do
      co = get_company
      billables = get_new_billables
      invoiceable_ids = get_new_invoiceable_ids(co)
      inv = create_invoice(co)
      bill_new_entries(billables, invoiceable_ids, inv)
      bill_monthly_charge inv
    end
  end

  def self.create_invoice(company)
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: company, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def self.get_company
    Company.where(master: true).first
  end

  def self.bill_monthly_charge invoice
    invoice.vfi_invoice_lines.create! vfi_invoice: invoice, charge_amount: 1000, quantity: 1, unit: "ea", unit_price: 1000, charge_description: "monthly charge"
  end

  def self.get_new_billables
    BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"').where('ie.id IS NULL')
  end

  def self.get_new_invoiceable_ids company
    BillableEvent.connection.execute(entry_query company).map(&:first)
  end

  def self.bill_new_entries new_billables, invoiceable_ids, invoice
    new_entries, others = split_billables(new_billables, invoiceable_ids)
    qty_to_bill = new_entries.count
    charge_amount = qty_to_bill * 2.50
    if qty_to_bill > 0
      line = invoice.vfi_invoice_lines.create! charge_amount: charge_amount, quantity: qty_to_bill, unit: "ea", unit_price: 2.50, charge_description: "new entry exceeding 250/mo. limit"
      write_invoiced_events new_entries, line
    else
      write_invoiced_events new_entries
    end
    write_invoiced_events others
  end

  def self.split_billables billables, invoiceable_ids
    billables.partition{ |b| invoiceable_ids.include? b[:billable_eventable_id] }
  end

  def self.write_invoiced_events billables, invoice_line=nil
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'MasterbrandInvoiceGenerator', charge_type: 'unified_entry_line')
      end
    end
  end

  private

  def self.entry_query company
    <<-SQL
      SELECT e.id
      FROM billable_events be
        INNER JOIN entries e ON be.billable_eventable_type = "Entry" AND be.billable_eventable_id = e.id
        INNER JOIN companies c ON c.id = e.importer_id
        LEFT OUTER JOIN invoiced_events ie ON be.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"
      WHERE ie.billable_event_id IS NULL 
        AND be.event_type = "entry_new"
        AND c.id = #{company.id}
        AND (e.file_logged_date >= "2016-05-01" OR e.file_logged_date IS NULL)
    SQL
  end

end; end; end; end