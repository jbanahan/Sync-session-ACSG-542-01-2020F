module OpenChain; module CustomHandler; module Masterbrand
  class MasterbrandInvoiceGenerator
    def self.run_schedulable
      generator = self.new
      new_billables = generator.get_new_billables
      co = Company.where(alliance_customer_number: "MBCI").first
      invoice = VfiInvoice.next_invoice_number { |num| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: num, currency: "USD") }
      generator.bill_entries(new_billables, invoice)
    end

    def bill_entries new_billables, invoice
      new_entries, others = split_billables new_billables
      write_invoiced_events others
      new_entry_count = new_entries.count
      if new_entry_count > 250
        qty_to_bill = new_entry_count - 250
        charge = qty_to_bill * 2.50
        line = invoice.vfi_invoice_lines.create!(line_number: 1, charge_amount: charge, quantity: qty_to_bill, unit: "ea", unit_price: 2.50, charge_description: "new entry exceeding 250/mo. limit")
        write_invoiced_events new_entries, line.id
      else
        write_invoiced_events new_entries
      end
    end

    def get_new_billables
      new_events = BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"').where('ie.billable_event_id IS NULL')
      new_events.map! do |billable|
        { billable_event_id: billable.id, entry_id: billable.eventable_id, event_type: billable.event_type, invoice_generator_name: 'MasterbrandInvoiceGenerator', charge_type: "unified entry line"} 
      end
    end

    private

    def split_billables new_billables
      new_billables.partition{ |c| c[:event_type] == "Entry - New"}
    end

    def write_invoiced_events billables, invoice_line_id=nil
      BillableEvent.transaction do
        billables.each do |e|
          InvoicedEvent.create!(billable_event_id: e[:billable_event_id], vfi_invoice_line_id: invoice_line_id, invoice_generator_name: e[:invoice_generator_name], charge_type: e[:charge_type])
        end
      end
    end

  end
end; end; end