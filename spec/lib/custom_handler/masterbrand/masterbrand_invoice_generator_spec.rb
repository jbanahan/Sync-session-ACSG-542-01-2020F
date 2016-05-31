require 'spec_helper'

describe OpenChain::CustomHandler::Masterbrand::MasterbrandInvoiceGenerator do
  
  def create_many_entries int
    int.times { Factory(:billable_event, eventable: Factory(:entry), event_type: "Entry - New") }
  end

  before :each do
  #creates billable_events tied to 1 old entry (has an invoiced_event) and 1 new classification
    Factory(:company, alliance_customer_number: "MBCI", name: "MasterBrand")
    billable_old = Factory(:billable_event, eventable: Factory(:entry), event_type: "Entry - New")
    @classification_billable = Factory(:billable_event, eventable: Factory(:entry), event_type: "Classification - New")
    @old_invoiced_event = Factory(:invoiced_event, billable_event: billable_old, invoice_generator_name: "MasterbrandInvoiceGenerator", charge_type: "unified entry line")
  end

  describe "run" do
    it "invoices new Entries when number over 250 and charges for business rules when number exceeds 20" do
      create_many_entries 253

      described_class.run_schedulable
      inv = VfiInvoice.first
      line = inv.vfi_invoice_lines.first
      expect(inv.customer.name).to eq "MasterBrand"
      expect(inv.invoice_number).to eq "VFI-1"
      expect(inv.invoice_date).to eq Date.today
      expect(line.charge_description).to eq "new entry exceeding 250/mo. limit"
    end
  end
  
  describe :bill_entries do
    it "creates an invoiced event for each new Masterbrand new-entry billable event; creates an invoice line charging for 3 new entries" do
      create_many_entries 253

      generator = described_class.new
      new_billables = generator.get_new_billables
      invoice = Factory(:vfi_invoice)

      expect(InvoicedEvent.count).to eq 1
      generator.bill_entries new_billables, invoice
      expect(InvoicedEvent.count).to eq 255
      inv_event = InvoicedEvent.last
      expect(inv_event.invoice_generator_name).to eq "MasterbrandInvoiceGenerator"
      expect(inv_event.charge_type).to eq "unified entry line"
      @old_invoiced_event.reload
      expect(@old_invoiced_event.vfi_invoice_line_id).to be_nil

      expect(VfiInvoiceLine.count).to eq 1
      inv_line = VfiInvoiceLine.first
      
      expect(inv_line.line_number).to eq 1
      expect(inv_line.charge_description).to eq "new entry exceeding 250/mo. limit"
      expect(inv_line.charge_amount).to eq 7.50
      expect(inv_line.quantity).to eq 3
      expect(inv_line.unit).to eq "ea"
      expect(inv_line.unit_price).to eq 2.50
    end

    it "adds no invoice lines when threshold not exceeded" do
      create_many_entries 3
      generator = described_class.new
      new_billables = generator.get_new_billables
      invoice = Factory(:vfi_invoice)

      expect(InvoicedEvent.count).to eq 1
      generator.bill_entries new_billables, invoice
      expect(InvoicedEvent.count).to eq 5
      expect(VfiInvoiceLine.count).to eq 0
    end
  end

end