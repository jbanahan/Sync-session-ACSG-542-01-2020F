require 'spec_helper'

describe OpenChain::CustomHandler::Hm::HmInvoiceGenerator do
  before :each do 
  #creates billable events tied to 3 new CA classifications, 1 new US classification, 1 old CA classification (has invoiced event), 1 new entry
      country_ca = Factory(:country, iso_code: 'CA')
      company = Factory(:company, alliance_customer_number: "HENNE", name: "H & M")
      prod = Factory(:product, importer: company)
      
      ca_class_new_1 = Factory(:classification, country: country_ca, product: prod)
      ca_class_new_2 = Factory(:classification, country: country_ca, product: Factory(:product, importer: company))
      ca_class_new_3 = Factory(:classification, country: country_ca, product: Factory(:product, importer: company))
      
      ca_class_old = Factory(:classification, country: country_ca, product: Factory(:product, importer: company))
      us_class_new = Factory(:classification, country: Factory(:country, iso_code: 'US'), product: prod)

      @new_us_1 = Factory(:billable_event, eventable: ca_class_new_1, event_type: "Classification - New")
      @new_us_2 = Factory(:billable_event, eventable: ca_class_new_2, event_type: "Classification - New")
      @new_us_3 = Factory(:billable_event, eventable: ca_class_new_3, event_type: "Classification - New")
      billable_old = Factory(:billable_event, eventable: ca_class_old, event_type: "Classification - New")
      
      Factory(:billable_event, eventable: us_class_new, event_type: "Classification - New")
      @entry_billable = Factory(:billable_event, eventable: Factory(:entry), event_type: "Entry - New")
      @old_invoiced_event = Factory(:invoiced_event, billable_event: billable_old, invoice_generator_name: "HmInvoiceGenerator", charge_type: "CA Classification")
    end

  describe "run" do
    it "invoices new CA classifications" do
      described_class.run_schedulable
      inv = VfiInvoice.first
      line = inv.vfi_invoice_lines.first
      expect(inv.customer.name).to eq "H & M"
      expect(inv.invoice_number).to eq "VFI-1"
      expect(inv.invoice_date).to eq Date.today
      expect(line.charge_description).to eq "new Canadian classification"
    end
  end

  describe :bill_ca_classifications do
    it "creates an invoiced event for each new H&M new-classification billable event; creates an invoice line charging for 3 new CA classifications" do
      generator = described_class.new
      new_billables = generator.get_new_billables
      invoice = Factory(:vfi_invoice)

      expect(InvoicedEvent.count).to eq 1
      generator.bill_ca_classifications new_billables, invoice
      expect(InvoicedEvent.count).to eq 6
      @old_invoiced_event.reload
      expect(@old_invoiced_event.vfi_invoice_line_id).to be_nil
      inv_event = InvoicedEvent.last
      expect(inv_event.invoice_generator_name).to eq "HmInvoiceGenerator"
      expect(inv_event.charge_type).to eq "CA classification"

      expect(VfiInvoiceLine.count).to eq 1
      inv_line = VfiInvoiceLine.first
      expect(inv_line.line_number).to eq 1
      expect(inv_line.charge_description).to eq "new Canadian classification"
      expect(inv_line.charge_amount).to eq 6
      expect(inv_line.quantity).to eq 3
      expect(inv_line.unit).to eq "ea"
      expect(inv_line.unit_price).to eq 2.00
    end

    it "adds no invoice lines when there are no new CA classifications" do
      [@new_us_1, @new_us_2, @new_us_3].each(&:destroy)
      generator = described_class.new
      new_billables = generator.get_new_billables
      invoice = Factory(:vfi_invoice)

      expect(InvoicedEvent.count).to eq 1
      generator.bill_ca_classifications new_billables, invoice
      expect(InvoicedEvent.count).to eq 3
      expect(VfiInvoiceLine.count).to eq 0
    end
  end

end