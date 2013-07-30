require 'spec_helper'

describe OpenChain::CustomHandler::Polo::PoloCaFenixInvoiceGenerator do

  context :invoice_header_map do
    it "the header map should nil out importer and handle blank invoice numbers" do
      invoice = CommercialInvoice.new
      invoice.id = 10

      m = described_class.new.invoice_header_map
      m[:invoice_number].call(invoice).should == "VFI-#{invoice.id}"

      invoice.invoice_number = "INV"
      m[:invoice_number].call(invoice).should == "INV"

      m[:importer].should be_nil
    end
  end

  context :generate do
    it "should call module's generate_and_send method" do
      described_class.any_instance.should_receive(:generate_and_send).with(5)
      described_class.generate 5
    end
  end

end