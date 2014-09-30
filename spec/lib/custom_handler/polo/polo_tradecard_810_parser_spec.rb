require 'spec_helper'

describe OpenChain::CustomHandler::Polo::PoloTradecard810Parser do

  before :each do 
    @xml = <<-XML
<?xml version="1.0"?>
<Invoices>
  <Invoice>
    <InvoiceDate>20131216</InvoiceDate>
    <InvoiceNumber>9586/13</InvoiceNumber>
    <InvoiceLine>
      <OrderNumber>CAN007629-0001001</OrderNumber>
      <Quantity>8</Quantity>
      <PartNumber>0687213ANTBN</PartNumber>
      <UnitOfMeasue>EA</UnitOfMeasue>
    </InvoiceLine>
    <InvoiceLine>
      <OrderNumber>CAN007630-0001001</OrderNumber>
      <Quantity>13</Quantity>
      <PartNumber>0691332BLSFT</PartNumber>
      <UnitOfMeasue>AS</UnitOfMeasue>
    </InvoiceLine>
  </Invoice>
</Invoices>
XML
  end

  describe "integration_folder" do
    it "uses the correct integration_folder" do
      expect(OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.integration_folder).to eq "/opt/wftpserver/ftproot/www-vfitrack-net/_polo_tradecard_810"
    end
  end

  describe "process_from_s3" do
    it "retrieves S3 data and parses it" do
      OpenChain::S3.should_receive(:get_data).with('abc', '123').and_return @xml
      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.process_from_s3 'abc', '123'

      inv = CommercialInvoice.first
      expect(inv).to_not be_nil
    end

  end

  describe "parse" do
   
    it "parses tradecard 810 xml" do
      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.parse @xml

      inv = CommercialInvoice.first
      expect(inv).to_not be_nil

      expect(inv.vendor_name).to eq "Tradecard"
      expect(inv.invoice_date).to eq Date.new(2013, 12, 16)
      expect(inv.invoice_number).to eq "9586/13"
      expect(inv.commercial_invoice_lines).to have(2).items

      line = inv.commercial_invoice_lines.first
      expect(line.po_number).to eq "CAN007629-0001001"
      expect(line.quantity).to eq BigDecimal.new("8")
      expect(line.part_number).to eq "0687213ANTBN"
      expect(line.unit_of_measure).to eq "EA"

      line = inv.commercial_invoice_lines.second
      expect(line.po_number).to eq "CAN007630-0001001"
      expect(line.quantity).to eq BigDecimal.new("13")
      expect(line.part_number).to eq "0691332BLSFT"
      expect(line.unit_of_measure).to eq "AS"
    end

    it "updates existing invoices" do
      line = Factory(:commercial_invoice_line, :commercial_invoice => Factory(:commercial_invoice, :vendor_name=>"Tradecard", :invoice_number=>"9586/13"))
      existing_inv = line.commercial_invoice

      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.parse @xml

      inv = CommercialInvoice.first
      expect(inv).to_not be_nil
      expect(inv.id).to eq existing_inv.id

      expect(inv.commercial_invoice_lines).to have(2).items
    end

    it "handles invalid dates without errors" do
      @xml.gsub!("<InvoiceDate>20131216</InvoiceDate>", "<InvoiceDate>ABCD</InvoiceDate>")

      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.parse @xml
      inv = CommercialInvoice.first
      expect(inv).to_not be_nil
      expect(inv.invoice_date).to be_nil
    end

    it "handles invalid quantities with errors" do
      @xml.gsub!("<Quantity>8</Quantity>", "<Quantity>ABC</Quantity>")

      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.parse @xml
      inv = CommercialInvoice.first
      expect(inv).to_not be_nil
      expect(inv.commercial_invoice_lines.first.quantity).to eq BigDecimal.new("0")
    end

    it "marks connected POs as received" do
      o = Order.create! order_number: "806167003RM0001-CAN007629", importer: Factory(:importer, fenix_customer_number: "806167003RM0001")
      cds = OpenChain::CustomHandler::Polo::PoloTradecard810Parser.prep_custom_definitions([:ord_invoiced, :ord_invoicing_system])
      o.update_custom_value! cds[:ord_invoicing_system], "Tradecard"

      OpenChain::CustomHandler::Polo::PoloTradecard810Parser.new.parse @xml
      expect(o.get_custom_value(cds[:ord_invoiced]).value).to be_true
    end
  end
end