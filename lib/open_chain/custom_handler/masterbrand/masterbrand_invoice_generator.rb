module OpenChain; module CustomHandler; module Masterbrand; class MasterbrandInvoiceGenerator
    
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
      invoice.vfi_invoice_lines.create! vfi_invoice: invoice, charge_amount: 1000, quantity: 1, unit: "ea", unit_price: 1000, charge_description: "monthly charge"
    end

    def self.get_new_billables
      BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "MasterbrandInvoiceGenerator"').where('ie.id IS NULL')
    end

    def self.bill_new_entries new_billables, invoice
      new_entries, others = split_billables new_billables
      qty_to_bill = new_entries.count - 250
      charge_amount = qty_to_bill * 2.50
      if qty_to_bill > 0
        line = invoice.vfi_invoice_lines.create! charge_amount: charge_amount, quantity: qty_to_bill, unit: "ea", unit_price: 2.50, charge_description: "new entry exceeding 250/mo. limit"
        write_invoiced_events new_entries, line
      else
        write_invoiced_events new_entries
      end
      write_invoiced_events others
    end

    def self.split_billables new_billables
      new_billables.partition{ |c| c[:event_type] == "entry_new"}
    end

    def self.write_invoiced_events billables, invoice_line=nil
      BillableEvent.transaction do
        billables.each do |e|
          InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'MasterbrandInvoiceGenerator', charge_type: 'unified_entry_line')
        end
      end
    end

end; end; end; end