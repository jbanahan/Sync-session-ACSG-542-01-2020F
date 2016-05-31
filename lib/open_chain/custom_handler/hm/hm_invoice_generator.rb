module OpenChain; module CustomHandler; module Hm
  class HmInvoiceGenerator

    def self.run_schedulable
      generator = self.new
      new_billables = generator.get_new_billables
      co = Company.where(alliance_customer_number: "HENNE").first
      invoice = VfiInvoice.next_invoice_number { |num| VfiInvoice.create!(customer: co, invoice_date: Date.today, invoice_number: num, currency: "USD") }
      generator.bill_ca_classifications(new_billables, invoice)
    end

    def bill_ca_classifications new_billables, invoice
      new_classifications, others = split_billables new_billables
      write_invoiced_events others
      new_class_count = new_classifications.count
      if new_class_count > 0
        charge = new_class_count * 2.00
        line = invoice.vfi_invoice_lines.create!(line_number: 1, charge_amount: charge, quantity: new_class_count, unit: "ea", unit_price: 2.00, charge_description: "new Canadian classification")
        write_invoiced_events new_classifications, line.id
      else
        write_invoiced_events new_classifications
      end
    end

    def get_new_billables
      new_events = BillableEvent.joins('LEFT OUTER JOIN invoiced_events ie ON billable_events.id = ie.billable_event_id AND ie.invoice_generator_name = "HmInvoiceGenerator"').where('ie.billable_event_id IS NULL')
      new_events.map! do |billable|
        { billable_event_id: billable.id, classification_id: billable.eventable_id, event_type: billable.event_type, invoice_generator_name: 'HmInvoiceGenerator', charge_type: "CA classification"} 
      end
    end
    
    private

    def ca_classification_qry
      <<-SQL
        SELECT cl.id
        FROM billable_events be
          INNER JOIN classifications cl ON be.eventable_type = "Classification" AND be.eventable_id = cl.id
          INNER JOIN products p ON p.id = cl.product_id
          INNER JOIN countries cou ON cou.id = cl.country_id
          INNER JOIN companies com ON com.id = p.importer_id
        WHERE com.alliance_customer_number = "HENNE" AND cou.iso_code = 'CA'        
      SQL
    end

    def split_billables new_billables
      ca_classification_ids = BillableEvent.connection.execute(ca_classification_qry).map(&:first)
      new_billables.partition{ |c| c[:event_type] == "Classification - New" && ca_classification_ids.include?(c[:classification_id])}
    end

    def write_invoiced_events billables, invoice_line_id=nil
      BillableEvent.transaction do
        billables.each do |c|
          InvoicedEvent.create!(billable_event_id: c[:billable_event_id], vfi_invoice_line_id: invoice_line_id, invoice_generator_name: c[:invoice_generator_name], charge_type: c[:charge_type])
        end
      end
    end
    
  end
end; end; end