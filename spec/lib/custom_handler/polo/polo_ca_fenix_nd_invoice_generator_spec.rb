require 'spec_helper'

describe OpenChain::CustomHandler::Polo::PoloCaFenixNdInvoiceGenerator do

  context "invoice_header_map" do
    it "the header map should nil out importer and handle blank invoice numbers" do
      invoice = CommercialInvoice.new
      invoice.id = 10

      m = described_class.new.invoice_header_map
      expect(m[:invoice_number].call(invoice)).to eq("VFI-#{invoice.id}")
    end
  end

  context "generate" do
    it "should call module's generate_and_send method" do
      expect_any_instance_of(described_class).to receive(:generate_and_send).with(5)
      described_class.generate 5
    end
  end

end