require 'spec_helper'

describe OpenChain::CustomHandler::Generic210Generator do

  describe "accepts?" do

    before :each do
      @entry = Factory(:entry, customer_number: "TEST")
      @master_setup = double("MasterSetup")
      MasterSetup.stub(:get).and_return @master_setup
      @master_setup.stub(:system_code).and_return "www-vfitrack-net"
    end

    it "accepts entries with a customer number linked to a sendable setup" do
      setup = AutomatedBillingSetup.create! customer_number: "TEST", enabled: true
      expect(described_class.new.accepts? :event, @entry).to be_true
    end

    it "does not accept setups that are not enabled" do
      setup = AutomatedBillingSetup.create! customer_number: "TEST", enabled: false
      expect(described_class.new.accepts? :event, @entry).to be_false
    end

    it "does not accept setups that don't have passing search criterions" do
      setup = AutomatedBillingSetup.create! customer_number: "TEST", enabled: true
      setup.search_criterions.create! model_field_uid: "ent_cust_num", operator: "eq", value: "123"
      expect(described_class.new.accepts? :event, @entry).to be_false
    end

    it "does not accept on non-www-vfitrack-net systems" do
      setup = AutomatedBillingSetup.create! customer_number: "TEST", enabled: true
      expect(described_class.new.accepts? :event, @entry).to be_true
    end
  end

  describe "receive" do
    
    before :each do
      @g = subject
      @ftped_files = []
      @g.stub(:ftp_file) do |tempfile|
        @ftped_files << tempfile.read
      end

      line = Factory(:broker_invoice_line, charge_type: "T", charge_amount: "50", charge_code: "CC", charge_description: "CDESC",
                      broker_invoice: Factory(:broker_invoice, invoice_number: "INV", invoice_total: 100, invoice_date: Date.new(2015, 1, 1), currency: "CAD", 
                        customer_number: "BT", bill_to_name: "BTN", bill_to_address_1: "BADD1", bill_to_address_2: "BADD2", bill_to_city: "BCITY", bill_to_state: "BST", bill_to_zip: "BZIP", bill_to_country: Factory(:country),
                        entry: Factory(:entry, broker_reference: "REF", entry_number: "ENT", customer_number: "CUST", carrier_code: "CARR",
                          lading_port_code: "LAD", unlading_port_code: "UNL", merchandise_description: "DESC", total_packages: 10, gross_weight: 10,
                          arrival_date: Date.new(2015, 2, 1), export_date: Date.new(2015, 3, 1), ult_consignee_name: "CONS", ult_consignee_code: "UC", consignee_address_1: "UADD1",
                          consignee_address_2: "UADD2", consignee_city: "UCITY", consignee_state: "UST", master_bills_of_lading: "A\nB", house_bills_of_lading: "C\nD", container_numbers: "E\nF",
                          po_numbers: "G\nH")

                    ))
      @broker_invoice = line.broker_invoice
      @entry = @broker_invoice.entry
      @setup = AutomatedBillingSetup.create! customer_number: @entry.customer_number, enabled: true
    end

    it "generates and sends a 210 xml file" do
      Lock.should_receive(:acquire).with("210-#{@entry.broker_reference}").and_yield
      @g.receive :save, @entry

      expect(@ftped_files.size).to eq 1
      xml = REXML::Document.new(@ftped_files.first).root

      expect(xml.name).to eq "Vfitrack210"
      expect(xml.text "BrokerReference").to eq "REF"
      expect(xml.text "EntryNumber").to eq "ENT"
      expect(xml.text "CustomerNumber").to eq "CUST"
      expect(xml.text "CarrierCode").to eq "CARR"
      expect(xml.text "PortOfLading").to eq "LAD"
      expect(xml.text "PortOfUnlading").to eq "UNL"
      expect(xml.text "DescriptionOfGoods").to eq "DESC"
      expect(xml.text "PieceCount").to eq "10"
      expect(xml.text "GrossWeight").to eq "10"
      expect(xml.text "ArrivalDate/Date").to eq "20150201"
      expect(xml.text "ArrivalDate/Time").to eq "0000"
      expect(xml.text "ExportDate/Date").to eq "20150301"
      expect(xml.text "ExportDate/Time").to eq "0000"
      expect(xml.text "Consignee/Name").to eq "CONS"
      expect(xml.text "Consignee/Id").to eq "UC"
      expect(xml.text "Consignee/Address1").to eq "UADD1"
      expect(xml.text "Consignee/Address2").to eq "UADD2"
      expect(xml.text "Consignee/City").to eq "UCITY"
      expect(xml.text "Consignee/State").to eq "UST"
      expect(xml.text "BillTo/Name").to eq "BTN"
      expect(xml.text "BillTo/Id").to eq "BT"
      expect(xml.text "BillTo/Address1").to eq "BADD1"
      expect(xml.text "BillTo/Address2").to eq "BADD2"
      expect(xml.text "BillTo/City").to eq "BCITY"
      expect(xml.text "BillTo/State").to eq "BST"
      expect(xml.text "BillTo/Zip").to eq "BZIP"
      expect(xml.text "BillTo/Country").to eq @broker_invoice.bill_to_country.iso_code

      expect(REXML::XPath.each(xml, "MasterBills/MasterBill").collect {|v| v.text}).to eq(["A", "B"])
      expect(REXML::XPath.each(xml, "HouseBills/HouseBill").collect {|v| v.text}).to eq(["C", "D"])
      expect(REXML::XPath.each(xml, "Containers/Container").collect {|v| v.text}).to eq(["E", "F"])
      expect(REXML::XPath.each(xml, "PoNumbers/PoNumber").collect {|v| v.text}).to eq(["G", "H"])

      expect(xml.text "Invoice/InitialInvoice").to eq "Y"
      expect(xml.text "Invoice/Number").to eq "INV"
      expect(xml.text "Invoice/Total").to eq "100.00"
      expect(xml.text "Invoice/Currency").to eq "CAD"
      expect(xml.text "Invoice/InvoiceDate/Date").to eq "20150101"
      expect(xml.text "Invoice/InvoiceDate/Time").to eq "0000"

      expect(xml.text "Invoice/Charge/LineNumber").to eq "1"
      expect(xml.text "Invoice/Charge/Type").to eq "T"
      expect(xml.text "Invoice/Charge/Amount").to eq "50.00"
      expect(xml.text "Invoice/Charge/Code").to eq "CC"
      expect(xml.text "Invoice/Charge/Description").to eq "CDESC"

      # make sure the sync record was created
      expect(@entry.sync_records.length).to eq 1
      expect(@entry.sync_records.first.fingerprint).to eq "INV"
    end

    it "sends one 210 per broker invoice" do
      line2 = Factory(:broker_invoice_line, charge_type: "T", charge_amount: "50", charge_code: "CC", charge_description: "CDESC",
                      broker_invoice: Factory(:broker_invoice, invoice_number: "INV2", invoice_total: 100, invoice_date: Date.new(2015, 1, 1), currency: "CAD", 
                        customer_number: "BT", bill_to_name: "BTN", bill_to_address_1: "BADD1", bill_to_address_2: "BADD2", bill_to_city: "BCITY", bill_to_state: "BST", bill_to_zip: "BZIP", bill_to_country: Factory(:country),
                        entry: @entry)
                     )

      @g.receive :save, @entry

      expect(@ftped_files.size).to eq 2
      # Just verify the two invoice numbers that should have been made are present in the xml output and the second one is not marked as initial
      expect(@ftped_files.map {|f| REXML::Document.new(f).root.text("Invoice/Number")}).to eq ["INV", "INV2"]
      expect(@ftped_files.map {|f| REXML::Document.new(f).root.text("Invoice/InitialInvoice")}).to eq ["Y", "N"]
    end

    it "doesn't send initial invoice flag if invoices previously sent" do
      @entry.sync_records.create! fingerprint: "Test", trading_partner: "210"

      @g.receive :save, @entry

      expect(@ftped_files.size).to eq 1
      xml = REXML::Document.new(@ftped_files.first).root
      expect(xml.text "Invoice/InitialInvoice").to eq "N"
    end

    it "strips duty lines if duty paid direct line is present" do
      duty_line = Factory(:broker_invoice_line, charge_type: "T", charge_amount: "50", charge_code: "0001", charge_description: "Duty",
                            broker_invoice: @broker_invoice)
      duty_direct_line = Factory(:broker_invoice_line, charge_type: "T", charge_amount: "50", charge_code: "0099", charge_description: "Duty Pd Direct",
                            broker_invoice: @broker_invoice)

      @broker_invoice.reload

      @g.receive :save, @entry
      expect(@ftped_files.size).to eq 1
      expect(REXML::XPath.each(REXML::Document.new(@ftped_files.first).root, "Invoice/Charge/Code").collect {|v| v.text}).to eq ["CC"]
    end

    it "strips accounting suppressed lines" do
      ["0097", "0098", "0099", "0105", "0106", "0107", "0600", "0601", "0602", "0603", "0604"].each {|c| @broker_invoice.broker_invoice_lines.create! charge_amount: 100, charge_code: c, charge_description: "#{c} Description"}

      @broker_invoice.reload

      @g.receive :save, @entry
      expect(@ftped_files.size).to eq 1
      expect(REXML::XPath.each(REXML::Document.new(@ftped_files.first).root, "Invoice/Charge/Code").collect {|v| v.text}).to eq ["CC"]
    end
  end
end
