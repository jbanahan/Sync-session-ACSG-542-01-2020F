require 'spec_helper'

describe OpenChain::CustomHandler::FootLocker::FootLocker810Generator do

  before :each do
    @h = described_class.new
  end

  describe "accepts?" do
    before :each do
      @ms = double("MasterSetup")
      MasterSetup.stub(:get).and_return @ms
      @ms.stub(:system_code).and_return "www-vfitrack-net"

      @e = Entry.new
      @e.last_billed_date = Time.zone.now
      @inv = @e.broker_invoices.build
    end
    
    it "accepts FOOLO entries that have been billed and have invoices" do
      @e.customer_number = 'FOOLO'
      expect(@h.accepts? nil, @e).to be_true
    end

    it "accepts FOOCA entries that have been billed and have invoices" do
      @e.customer_number = 'FOOCA'
      expect(@h.accepts? nil, @e).to be_true
    end

    it "accepts TEAED entries that have been billed and have invoices" do
      @e.customer_number = 'TEAED'
      expect(@h.accepts? nil, @e).to be_true
    end
    
    it "does not accept entries that don't have invoices" do
      @e.customer_number = 'FOOLO'
      @e.broker_invoices.clear
      expect(@h.accepts? nil, @e).to be_false
    end

    it "does not accept entries that have not been billed" do
      @e.customer_number = 'FOOLO'
      @e.last_billed_date = nil
      expect(@h.accepts? nil, @e).to be_false
    end

    it "does not accept entries on other systems" do
      @ms.stub(:system_code).and_return "another system"

      @e.customer_number = 'FOOLO'
      expect(@h.accepts? nil, @e).to be_false
    end
  end

  describe "receive" do

    def xp xpath, index = nil
      result = nil
      if index
        m = REXML::XPath.match(@xml, xpath)
        if m
          m = m[index]
          result = m.try(:text)
        end
      else
        result = REXML::XPath.first(@xml, xpath).try(:text)
      end
      result
    end

    def validate_charge_line index, ct, cc, cd, ca
      expect(xp "Lines/Line/Type", index).to eq ct
      expect(xp "Lines/Line/Code", index).to eq cc
      expect(xp "Lines/Line/Description", index).to eq cd
      expect(xp "Lines/Line/Amount", index).to eq ca
    end

    before :each do
      @ftp_files = []
      @h.stub(:ftp_file) do |file|
        @ftp_files << file.read
      end

      @entry = Factory(:entry, master_bills_of_lading: "MB1\nMB2", house_bills_of_lading: "HB1\nHB2", broker_reference: "REF", entry_number: "NUM", entry_type: "TYPE", export_date: Date.new(2014, 11, 1), 
        release_date: Date.new(2014, 11, 2), entry_filed_date: Date.new(2014, 11, 3), entry_port_code: "CD", vessel: "VESS", voyage: "VOY", carrier_code: "CAR", unlading_port_code: "UNL", 
        entry_port_code: "EPC", lading_port_code: "LPC", total_invoiced_value: "666.66", hmf: "123.45", mpf: "234.56", cotton_fee: "345.67", total_duty: "456.78", arrival_date: Date.new(2014, 11, 4))

      @invoice = Factory(:broker_invoice, invoice_number: "INV1", invoice_date: Date.new(2014, 11, 1), invoice_total: "100.99", entry: @entry)
      @invoice.broker_invoice_lines << Factory(:broker_invoice_line, broker_invoice: @invoice, charge_type: "1", charge_code: "Code", charge_description: "Desc", charge_amount: "50.00")
      @invoice.broker_invoice_lines << Factory(:broker_invoice_line, broker_invoice: @invoice, charge_type: "2", charge_code: "Code2", charge_description: "Desc2", charge_amount: "25.00")
      # Duty Paid direct lines should be included...FOLO wants these for reporting purposes
      @dpd_line = Factory(:broker_invoice_line, broker_invoice: @invoice, charge_type: "D", charge_code: "0099", charge_description: "Duty Paid Direct", charge_amount: "10.00")
      @invoice.broker_invoice_lines << @dpd_line

      @com_invoice = Factory(:commercial_invoice, entry: @entry)
      @tar1 = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: @com_invoice, po_number: "PO#"))
      @tar2 = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: @com_invoice, po_number: "PO#"))
      @tar3 = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: @com_invoice, po_number: "PO#2"))
      @entry.reload
    end

    it "generates and sends xml for entry's invoices" do
      @h.receive nil, @entry
      expect(@ftp_files.size).to eq 1

      expect(@entry.sync_records.size).to eq 1
      sr = @entry.sync_records.first
      expect(sr.fingerprint).to eq @invoice.invoice_number
      expect(sr.sent_at.to_date).to eq Time.zone.now.to_date
      expect(sr.confirmed_at.to_date).to eq Time.zone.now.to_date

      @xml = REXML::Document.new(@ftp_files[0]).root

      expect(@xml.name).to eq "FootLockerInvoice810"
      expect(xp "InvoiceNumber").to eq @invoice.invoice_number
      expect(xp "InvoiceDate").to eq @invoice.invoice_date.iso8601
      expect(xp "MasterBill", 0).to eq "MB1"
      expect(xp "MasterBill", 1).to eq "MB2"
      expect(xp "HouseBill", 0).to eq "HB1"
      expect(xp "HouseBill", 1).to eq "HB2"
      expect(xp "FileNumber").to eq @entry.broker_reference
      expect(xp "EntryNumber").to eq @entry.entry_number
      expect(xp "CustomsEntryTypeCode").to eq @entry.entry_type
      expect(xp "RemitToName").to eq "Vandegrift Forwarding Company, Inc."
      expect(xp "RemitToAdd1").to eq "100 Walnut Ave."
      expect(xp "RemitToAdd2").to eq "Suite 600"
      expect(xp "RemitToCity").to eq "Clark"
      expect(xp "RemitToState").to eq "NJ"
      expect(xp "RemitToPostal").to eq "07066"
      expect(xp "ShippedDate").to eq @entry.export_date.iso8601
      expect(xp "CustomsClearance").to eq @entry.release_date.in_time_zone("Eastern Time (US & Canada)").to_date.iso8601
      expect(xp "EntryFiledDate").to eq @entry.entry_filed_date.in_time_zone("Eastern Time (US & Canada)").to_date.iso8601
      expect(xp "ArrivalDate").to eq @entry.arrival_date.in_time_zone("Eastern Time (US & Canada)").to_date.iso8601
      expect(xp "ActualPortOfEntry").to eq @entry.entry_port_code
      expect(xp "VesselName").to eq @entry.vessel
      expect(xp "FlightVoyageNumber").to eq @entry.voyage
      expect(xp "SCAC").to eq @entry.carrier_code
      expect(xp "PortOfDischarge").to eq @entry.unlading_port_code
      expect(xp "PortOfEntry").to eq @entry.entry_port_code
      expect(xp "PortOfLoading").to eq @entry.lading_port_code
      expect(xp "TotalMonetaryAmount").to eq @h.number_with_precision(@invoice.invoice_total, precision: 2)
      expect(xp "TotalCommercialInvoiceAmount").to eq @h.number_with_precision(@entry.total_invoiced_value, precision: 2)
      expect(xp "Details/Detail/PoNumber", 0).to eq @tar1.commercial_invoice_line.po_number
      expect(xp "Details/Detail/Tariff", 0).to eq @tar1.hts_code
      expect(xp "Details/Detail/PoNumber", 1).to eq @tar3.commercial_invoice_line.po_number
      expect(xp "Details/Detail/Tariff", 1).to eq @tar3.hts_code

      expect(REXML::XPath.match(@xml, "Lines/Line").size).to eq 7

      validate_charge_line 0, "D", "HMF", "HMF FEE", @h.number_with_precision(@entry.hmf, precision: 2)
      validate_charge_line 1, "D", "MPF", "MPF FEE", @h.number_with_precision(@entry.mpf, precision: 2)
      validate_charge_line 2, "D", "CTN", "COTTON FEE", @h.number_with_precision(@entry.cotton_fee, precision: 2)
      validate_charge_line 3, "D", "0001", "DUTY", @h.number_with_precision(@entry.total_duty, precision: 2)

      bil = @invoice.broker_invoice_lines[0]
      validate_charge_line 4, bil.charge_type, bil.charge_code, bil.charge_description, @h.number_with_precision(bil.charge_amount, precision: 2)
      bil = @invoice.broker_invoice_lines[1]
      validate_charge_line 5, bil.charge_type, bil.charge_code, bil.charge_description, @h.number_with_precision(bil.charge_amount, precision: 2)
      bil = @invoice.broker_invoice_lines[2]
      validate_charge_line 6, bil.charge_type, bil.charge_code, bil.charge_description, @h.number_with_precision(bil.charge_amount, precision: 2)
    end

    it "does not resend sent invoices" do
      @entry.sync_records.create! trading_partner: "foolo 810", fingerprint: @invoice.invoice_number
      @h.receive nil, @entry
      expect(@ftp_files.size).to eq 0
    end

    it "sends additional invoices, but doesn't include duty charges" do
      # This ir really just checking that invoices w/ suffixes don't incldue the duty data from the entry
      inv = @invoice.invoice_number
      @entry.sync_records.create! trading_partner: "foolo 810", fingerprint: inv
      @invoice.update_attributes! invoice_number: inv + "A", suffix: "A"
      @h.receive nil, @entry
      expect(@ftp_files.size).to eq 1

      @xml = REXML::Document.new(@ftp_files[0]).root

      # Since the duty charge lines shouldn't be included, the charges on the invoices should be the
      # the first and second lines
      bil = @invoice.broker_invoice_lines[0]
      validate_charge_line 0, bil.charge_type, bil.charge_code, bil.charge_description, @h.number_with_precision(bil.charge_amount, precision: 2)
      bil = @invoice.broker_invoice_lines[1]
      validate_charge_line 1, bil.charge_type, bil.charge_code, bil.charge_description, @h.number_with_precision(bil.charge_amount, precision: 2)
    end

    it "skips duty lines on invoices and doesn't send xml without any lines" do
      @dpd_line.destroy
      @invoice.reload

      @invoice.broker_invoice_lines.each do |l|
        l.update_attributes! charge_type: "D"
      end

      # Primary invoices are goign always include duty information, so they'll never be suppressed,
      # test w/ a follow-up invoice
      inv = @invoice.invoice_number
      @entry.sync_records.create! trading_partner: "foolo 810", fingerprint: inv
      @invoice.update_attributes! invoice_number: inv + "A", suffix: "A"
      @h.receive nil, @entry
      expect(@ftp_files.size).to eq 0
    end

    it "adds Details element even if there are no details" do
      # blank the PO numbers so we don't generate detail lines
      @com_invoice.commercial_invoice_lines.each {|ci| 
        ci.update_attributes! po_number: nil
        ci.commercial_invoice_tariffs.each {|t| t.update_attributes! hts_code: nil}
      }


      @h.receive nil, @entry
      expect(@ftp_files.size).to eq 1
      @xml = REXML::Document.new(@ftp_files[0]).root

      # Verify we have a blank Details element
      x = REXML::XPath.match(@xml, "Details")
      expect(x[0].name).to eq "Details"
      expect(REXML::XPath.match(@xml, "Details/Detail").length).to eq 1
      expect(REXML::XPath.match(@xml, "Details/Detail")[0].text("PoNumber")).to eq "0"
      expect(REXML::XPath.match(@xml, "Details/Detail")[0].text("Tariff")).to be_nil
    end

    it "sends tariffs even if po number is missing" do
      # blank the PO numbers so we don't generate detail lines
      @com_invoice.commercial_invoice_lines.each {|ci| 
        ci.update_attributes! po_number: nil
      }


      @h.receive nil, @entry
      expect(@ftp_files.size).to eq 1
      @xml = REXML::Document.new(@ftp_files[0]).root

      # Verify we have a blank Details element
      x = REXML::XPath.match(@xml, "Details")
      expect(x[0].name).to eq "Details"
      expect(REXML::XPath.match(@xml, "Details/Detail").length).to eq 1
      expect(REXML::XPath.match(@xml, "Details/Detail")[0].text("PoNumber")).to eq "0"
      expect(REXML::XPath.match(@xml, "Details/Detail")[0].text("Tariff")).to eq "1234"
    end
  end
end