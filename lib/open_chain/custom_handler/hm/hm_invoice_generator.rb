module OpenChain; module CustomHandler; module Hm; class HmInvoiceGenerator

  UNIT_PRICE = 2.00
  
  def self.run_schedulable
    ActiveRecord::Base.transaction do
      billables = get_new_billables
      inv = create_invoice
      bill_new_classifications(billables, inv)
    end
  end

  def self.get_new_billables
    BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "HmInvoiceGenerator"')
                 .joins('INNER JOIN classifications cla ON cla.id = billable_eventable_id INNER JOIN countries cou ON cou.id = cla.country_id AND cou.iso_code = "CA" INNER JOIN products p ON cla.product_id = p.id INNER JOIN companies com ON com.id = p.importer_id AND com.alliance_customer_number = "HENNE"')
                 .where('ie.id IS NULL')
                 .where('billable_eventable_type = "Classification"')
  end

  def self.create_invoice
    co = Company.where(alliance_customer_number: "HENNE").first
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def self.bill_new_classifications billables, invoice
    qty_to_bill = billables.count
    if qty_to_bill > 0
      line = invoice.vfi_invoice_lines.create!(charge_description: "Canadian classification", quantity: qty_to_bill, unit: "ea", unit_price: UNIT_PRICE)
      write_invoiced_events(billables, line)
    end
  end

  def self.write_invoiced_events billables, invoice_line
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'HmInvoiceGenerator', charge_type: 'classification_ca')
      end
    end
  end

end; end; end; end