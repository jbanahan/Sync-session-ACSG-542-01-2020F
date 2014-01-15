require 'spec_helper'

describe OpenChain::CustomHandler::Crocs::Crocs210Generator do

  before :each do
    @g = described_class.new
  end

  describe "accepts?" do
    it "accepts 'CROCS' entries with broker invoices" do
      line = Factory(:broker_invoice_line,
        broker_invoice: Factory(:broker_invoice,
          entry: Factory(:entry, customer_number: "CROCS")
        )
      )

      expect(described_class.new.accepts?(:save, line.broker_invoice.entry)).to be_true
    end

    it "accepts 'CROCSSAM' entries with broker invoices" do
      line = Factory(:broker_invoice_line,
        broker_invoice: Factory(:broker_invoice,
          entry: Factory(:entry, customer_number: "CROCSSAM")
        )
      )

      expect(described_class.new.accepts?(:save, line.broker_invoice.entry)).to be_true
    end

    it "doesn't accept entries without broker invoices" do
      expect(described_class.new.accepts?(:save, Factory(:entry, customer_number: "CROCS"))).to be_false
    end
  end

  describe "ftp_credentials" do
    it "uses ftp2 credentials with crocs ftp path" do
      g = described_class.new
      g.should_receive(:ftp2_vandegrift_inc).with("to_ecs/Crocs/210").and_return {}
      g.ftp_credentials
    end
  end

  describe "generate_xml" do
    before :each do
      line = Factory(:broker_invoice_line, charge_type: "R", charge_amount: 20, charge_description: "Charge", charge_code: "1234",
          broker_invoice: Factory(:broker_invoice, invoice_total: 50, currency: "CAD", invoice_number: "A",
            entry: Factory(:entry, broker_reference: "12345", entry_number: "65432", lading_port_code: "1", unlading_port_code: "2",
              merchandise_description: "GOODS", total_packages: 10, gross_weight: 20, arrival_date: Time.zone.now, ult_consignee_name: "CONSIGNEE",
              importer: Factory(:company, name: "Importer")
            )
          )
      )
      line2 = Factory(:broker_invoice_line, charge_type: "O", charge_amount: 20, charge_description: "Charge", charge_code: "1234", broker_invoice: line.broker_invoice)
      line3 = Factory(:broker_invoice_line, charge_type: "C", charge_amount: 20, charge_description: "Charge", charge_code: "1234", broker_invoice: line.broker_invoice)

      @invoice = line.broker_invoice
      @invoice.entry.importer.addresses.create! name: "210", line_1: "123 Fake St", city: "City", state: "St", postal_code: "123456"      
    end

    it "generates xml for invoices" do
      x = @g.generate_xml [@invoice]

      x.root.name.should eq "Crocs210"
      expect(REXML::XPath.first(x, "/Crocs210/FileNumber").text).to eq "12345"
      expect(REXML::XPath.first(x, "/Crocs210/EntryNumber").text).to eq "65432"
      expect(REXML::XPath.first(x, "/Crocs210/PortOfLading").text).to eq "1"
      expect(REXML::XPath.first(x, "/Crocs210/PortOfUnlading").text).to eq "2"
      expect(REXML::XPath.first(x, "/Crocs210/DescriptionOfGoods").text).to eq "GOODS"
      expect(REXML::XPath.first(x, "/Crocs210/PieceCount").text).to eq "10"
      expect(REXML::XPath.first(x, "/Crocs210/GrossWeight").text).to eq "20"
      expect(REXML::XPath.first(x, "/Crocs210/ArrivalDate").text).to eq Time.zone.now.in_time_zone("Eastern Time (US & Canada)").to_date.to_s
      expect(REXML::XPath.first(x, "/Crocs210/ConsigneeName").text).to eq "CONSIGNEE"
      i = @invoice.entry.importer
      expect(REXML::XPath.first(x, "/Crocs210/ImporterName").text).to eq "Importer"
      expect(REXML::XPath.first(x, "/Crocs210/ImporterAddress").text).to eq "123 Fake St"
      expect(REXML::XPath.first(x, "/Crocs210/ImporterCity").text).to eq "City"
      expect(REXML::XPath.first(x, "/Crocs210/ImporterState").text).to eq "St"
      expect(REXML::XPath.first(x, "/Crocs210/ImporterZip").text).to eq "123456"

      expect(REXML::XPath.match(x, "/Crocs210/Invoice").length).to eq 1

      expect(REXML::XPath.first(x, "/Crocs210/Invoice/Number").text).to eq "A"
      expect(REXML::XPath.first(x, "/Crocs210/Invoice/Total").text).to eq "50.00"
      expect(REXML::XPath.first(x, "/Crocs210/Invoice/Currency").text).to eq "CAD"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge").length).to eq 3

      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Type")[0].text).to eq "R"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Code")[0].text).to eq "1234"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Description")[0].text).to eq "Charge"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Amount")[0].text).to eq "20.00"

      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Type")[1].text).to eq "O"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Code")[1].text).to eq "1234"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Description")[1].text).to eq "Charge"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Amount")[1].text).to eq "20.00"

      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Type")[2].text).to eq "C"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Code")[2].text).to eq "1234"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Description")[2].text).to eq "Charge"
      expect(REXML::XPath.match(x, "/Crocs210/Invoice/Charge/Amount")[2].text).to eq "20.00"
    end

    it "skips lines that aren't R, O, C charge types" do
      @invoice.broker_invoice_lines.update_all charge_type: "X"

      # If there's no charge lines included, the xml should be blank as well
      expect(@g.generate_xml([@invoice])).to be_nil
    end

    it "skips invoices without any valid lines" do
      invoice_2 = Factory(:broker_invoice_line, charge_type: "X", charge_amount: 20, charge_description: "Charge", charge_code: "1234",
              broker_invoice: Factory(:broker_invoice, invoice_total: 100, currency: "CAD", invoice_number: "B", entry: @invoice.entry)).broker_invoice

      x = @g.generate_xml [@invoice, invoice_2]
      expect(REXML::XPath.match(x, "/Crocs210/Invoice").length).to eq 1
      expect(REXML::XPath.first(x, "/Crocs210/Invoice/Number").text).to eq "A"
    end
  end

  describe "receive" do

    before :each do
      @invoice = Factory(:broker_invoice_line, charge_type: "R", charge_amount: 20, charge_description: "Charge", charge_code: "1234",
            broker_invoice: Factory(:broker_invoice, invoice_total: 50, currency: "CAD", invoice_number: "A",
              entry: Factory(:entry, broker_reference: "12345", entry_number: "65432", lading_port_code: "1", unlading_port_code: "2",
                merchandise_description: "GOODS", total_packages: 10, gross_weight: 20, arrival_date: Time.zone.now, ult_consignee_name: "CONSIGNEE",
                importer: Factory(:company, name: "Importer")
              )
            )
        ).broker_invoice
    end

    it "generates xml and ftps it" do
      contents = nil
      @g.should_receive(:ftp_file) do |t|
        contents = IO.read(t.path)
      end

      @g.receive :save, @invoice.entry

      expect(contents).to_not be_nil
      xml = REXML::Document.new(contents)
      expect(REXML::XPath.first(xml, "/Crocs210/Invoice/Number").text).to eq "A"

      expect(@invoice.entry.sync_records.first.fingerprint).to eq "A"
      expect(@invoice.entry.sync_records.first.sent_at).to_not be_nil
      expect(@invoice.entry.sync_records.first.confirmed_at).to be >= (@invoice.entry.sync_records.first.sent_at + 1.minute)
    end

    it "skips invoices already sent but sends unsent ones" do
      invoice_2 = Factory(:broker_invoice_line, charge_type: "S", charge_amount: 20, charge_description: "Charge", charge_code: "1234",
              broker_invoice: Factory(:broker_invoice, invoice_total: 100, currency: "CAD", invoice_number: "B", entry: @invoice.entry)).broker_invoice

      @invoice.entry.sync_records.create! trading_partner: "crocs 210", fingerprint: "B\nC"

      contents = nil
      @g.should_receive(:ftp_file) do |t|
        contents = IO.read(t.path)
      end

      @g.receive :save, @invoice.entry

      expect(contents).to_not be_nil
      xml = REXML::Document.new(contents)
      expect(REXML::XPath.first(xml, "/Crocs210/Invoice/Number").text).to eq "A"

      expect(@invoice.entry.sync_records.first.fingerprint).to eq "B\nC\nA"
    end

    it "does not generate xml for files already sent" do
      @invoice.entry.sync_records.create! trading_partner: "crocs 210", fingerprint: "B\nA\nC"
      @g.should_not_receive(:ftp_file)
      @g.receive :save, @invoice.entry
    end
  end
end