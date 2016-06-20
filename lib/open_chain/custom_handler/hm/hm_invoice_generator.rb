module OpenChain; module CustomHandler; module Hm; class HmInvoiceGenerator

  UNIT_PRICE = 2.00
  
  def self.run_schedulable
    ActiveRecord::Base.transaction do
      billables = get_new_billables
      invoiceable_ids = get_new_invoiceable_ids
      inv = create_invoice
      bill_new_classifications(billables, invoiceable_ids, inv)
    end
  end

  def self.get_new_billables
    BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "HmInvoiceGenerator"').where('ie.id IS NULL')
  end

  def self.get_new_invoiceable_ids
    BillableEvent.connection.execute(ca_classification_qry).map(&:first)
  end

  def self.create_invoice
    co = Company.where(alliance_customer_number: "HENNE").first
    VfiInvoice.next_invoice_number { |n| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: n, currency: "USD")}
  end

  def self.bill_new_classifications billables, invoiceable_ids, invoice
    to_be_invoiced, others = split_billables(billables, invoiceable_ids)
    qty_to_bill = to_be_invoiced.count
    if qty_to_bill > 0
      line = invoice.vfi_invoice_lines.create!(charge_description: "new Canadian classification", quantity: qty_to_bill, unit: "ea", unit_price: UNIT_PRICE)
      write_invoiced_events(to_be_invoiced, line)
    end
    write_invoiced_events others
  end

  def self.split_billables billables, invoiceable_ids
    billables.partition{ |b| invoiceable_ids.include? b[:billable_eventable_id] }
  end

  def self.write_invoiced_events billables, invoice_line=nil
    BillableEvent.transaction do
      billables.each do |e|
        InvoicedEvent.create!(billable_event_id: e[:id], vfi_invoice_line: invoice_line, invoice_generator_name: 'HmInvoiceGenerator', charge_type: 'classification_ca')
      end
    end
  end

  private

  def self.ca_classification_qry
    <<-SQL
      SELECT cl.id
      FROM billable_events be
        INNER JOIN classifications cl ON be.billable_eventable_type = "Classification" AND be.billable_eventable_id = cl.id
        INNER JOIN products p ON p.id = cl.product_id
        INNER JOIN countries cou ON cou.id = cl.country_id
        INNER JOIN companies com ON com.id = p.importer_id
        LEFT OUTER JOIN invoiced_events ie ON be.id = ie.billable_event_id AND ie.invoice_generator_name = "HmInvoiceGenerator"
      WHERE com.alliance_customer_number = "HENNE" AND cou.iso_code = 'CA' AND ie.billable_event_id IS NULL AND be.event_type ='classification_new'
    SQL
  end

end; end; end; end