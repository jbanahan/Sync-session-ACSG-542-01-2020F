require 'spec_helper'

describe OpenChain::CustomHandler::FootLocker::FootLocker810Generator do

  describe "generate_xml" do

    def xp xml, xpath, index = nil
      xml = xml.root
      result = nil
      if index
        m = REXML::XPath.match(xml, xpath)
        if m
          m = m[index]
          result = m.try(:text)
        end
      else
        result = REXML::XPath.first(xml, xpath).try(:text)
      end
      result
    end

    def validate_charge_line xml, index, ct, cc, cd, ca
      expect(xp xml, "Lines/Line/Type", index).to eq ct
      expect(xp xml, "Lines/Line/Code", index).to eq cc
      expect(xp xml, "Lines/Line/Description", index).to eq cd
      expect(xp xml, "Lines/Line/Amount", index).to eq ca
    end

    let (:entry) {
      entry = Factory(:entry, master_bills_of_lading: "MB1\nMB2", house_bills_of_lading: "HB1\nHB2", broker_reference: "REF", entry_number: "NUM", entry_type: "TYPE", export_date: Date.new(2014, 11, 1), 
        release_date: "2014-11-02 12:00", entry_filed_date: "2014-11-03 12:00", vessel: "VESS", voyage: "VOY", carrier_code: "CAR", unlading_port_code: "UNL", 
        entry_port_code: "EPC", lading_port_code: "LPC", total_invoiced_value: "666.66", hmf: "123.45", mpf: "234.56", cotton_fee: "345.67", total_duty: "456.78", arrival_date: "2014-11-04 12:00")
      
    }

    let (:commercial_invoice) {
      com_invoice = Factory(:commercial_invoice, invoice_number: "COMINV", entry: entry)
      # Line 1 and 2 will be the same detail data, so they will be squeezed into a single line on the xml
      tar1 = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: com_invoice, po_number: "PO#", part_number: "part1"))
      tar2 = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: com_invoice, po_number: "PO#", part_number: "part1"))
      tar3 = Factory(:commercial_invoice_tariff, hts_code: "1234", commercial_invoice_line: Factory(:commercial_invoice_line, commercial_invoice: com_invoice, po_number: "PO#2", part_number: "part3"))
      com_invoice
    }

    let (:broker_invoice) {
      invoice = Factory(:broker_invoice, invoice_number: "INV1", invoice_date: Date.new(2014, 11, 1), invoice_total: "100.99", entry: entry)
      invoice.broker_invoice_lines << Factory(:broker_invoice_line, broker_invoice: invoice, charge_type: "1", charge_code: "Code", charge_description: "Desc", charge_amount: "50.00")
      invoice.broker_invoice_lines << Factory(:broker_invoice_line, broker_invoice: invoice, charge_type: "2", charge_code: "Code2", charge_description: "Desc2", charge_amount: "25.00")
      # Duty Paid direct lines should be included...FOLO wants these for reporting purposes
      dpd_line = Factory(:broker_invoice_line, broker_invoice: invoice, charge_type: "D", charge_code: "0099", charge_description: "Duty Paid Direct", charge_amount: "10.00")
      invoice.broker_invoice_lines << dpd_line

      invoice
    }

    it "generates and sends xml for entry's invoices" do
      commercial_invoice
      xml = subject.generate_xml broker_invoice

      expect(xml.root.name).to eq "FootLockerInvoice810"
      expect(xp xml, "InvoiceNumber").to eq "INV1"
      expect(xp xml, "InvoiceDate").to eq "2014-11-01"
      expect(xp xml, "MasterBill", 0).to eq "MB1"
      expect(xp xml, "MasterBill", 1).to eq "MB2"
      expect(xp xml, "HouseBill", 0).to eq "HB1"
      expect(xp xml, "HouseBill", 1).to eq "HB2"
      expect(xp xml, "FileNumber").to eq "REF"
      expect(xp xml, "EntryNumber").to eq "NUM"
      expect(xp xml, "CustomsEntryTypeCode").to eq "TYPE"
      expect(xp xml, "RemitToName").to eq "Vandegrift Forwarding Company, Inc."
      expect(xp xml, "RemitToAdd1").to eq "100 Walnut Ave."
      expect(xp xml, "RemitToAdd2").to eq "Suite 600"
      expect(xp xml, "RemitToCity").to eq "Clark"
      expect(xp xml, "RemitToState").to eq "NJ"
      expect(xp xml, "RemitToPostal").to eq "07066"
      expect(xp xml, "ShippedDate").to eq "2014-11-01"
      expect(xp xml, "CustomsClearance").to eq "2014-11-02"
      expect(xp xml, "EntryFiledDate").to eq "2014-11-03"
      expect(xp xml, "ArrivalDate").to eq "2014-11-04"
      expect(xp xml, "ActualPortOfEntry").to eq "EPC"
      expect(xp xml, "VesselName").to eq "VESS"
      expect(xp xml, "FlightVoyageNumber").to eq "VOY"
      expect(xp xml, "SCAC").to eq "CAR"
      expect(xp xml, "PortOfDischarge").to eq "UNL"
      expect(xp xml, "PortOfEntry").to eq "EPC"
      expect(xp xml, "PortOfLoading").to eq "LPC"
      expect(xp xml, "TotalMonetaryAmount").to eq "100.99"
      expect(xp xml, "TotalCommercialInvoiceAmount").to eq "666.66"

      expect(xp xml, "Details/Detail/PoNumber", 0).to eq "PO#"
      expect(xp xml, "Details/Detail/Tariff", 0).to eq "1234"
      expect(xp xml, "Details/Detail/Sku", 0).to eq "part1"
      expect(xp xml, "Details/Detail/InvoiceNumber", 0).to eq "COMINV"
      # The second tariff is skipped, because it has the same part/hts as the first
      expect(xp xml, "Details/Detail/PoNumber", 1).to eq "PO#2"
      expect(xp xml, "Details/Detail/Tariff", 1).to eq "1234"
      expect(xp xml, "Details/Detail/Sku", 1).to eq "part3"
      expect(xp xml, "Details/Detail/InvoiceNumber", 1).to eq "COMINV"

      expect(REXML::XPath.match(xml.root, "Lines/Line").size).to eq 7

      validate_charge_line xml, 0, "D", "HMF", "HMF FEE", "123.45"
      validate_charge_line xml, 1, "D", "MPF", "MPF FEE", "234.56"
      validate_charge_line xml, 2, "D", "CTN", "COTTON FEE", "345.67"
      validate_charge_line xml, 3, "D", "0001", "DUTY", "456.78"
      validate_charge_line xml, 4, "1", "Code", "Desc", "50.00"
      validate_charge_line xml, 5, "2", "Code2", "Desc2", "25.00"
      validate_charge_line xml, 6, "D", "0099", "Duty Paid Direct", "10.00"
    end

    it "sends additional invoices, but doesn't include duty charges" do
      # This is really just checking that invoices w/ suffixes don't incldue the duty data from the entry
      broker_invoice.update_attributes! invoice_number: (broker_invoice.invoice_number + "A"), suffix: "A"
      commercial_invoice
      xml = subject.generate_xml broker_invoice


      # Since the duty charge lines shouldn't be included, the charges on the invoices should be the
      # the first and second lines
      validate_charge_line xml, 0, "1", "Code", "Desc", "50.00"
      validate_charge_line xml, 1, "2", "Code2", "Desc2", "25.00"
    end

    it "skips duty lines on invoices and doesn't send xml without any lines" do
      # The point here is to remove the Duty Paid Direct line, so it's not sent, and then mark the others
      # as duty so they're skipped...if there's no lines, then the xml should be blank
      broker_invoice.broker_invoice_lines.where(charge_type: "D").destroy_all
      broker_invoice.broker_invoice_lines.update_all(charge_type: "D")
      broker_invoice.reload

      # Primary invoices are always going to include duty information, so they'll never be suppressed,
      # Test w/ an invoice that has a suffix
      broker_invoice.update_attributes! invoice_number: (broker_invoice.invoice_number + "A"), suffix: "A"

      commercial_invoice
      expect(subject.generate_xml broker_invoice).to be_nil
    end

    it "adds Details element even if there are no details" do
      # blank the PO numbers so we don't generate detail lines
      commercial_invoice.commercial_invoice_lines.each {|ci| 
        ci.update_attributes! po_number: nil
        ci.commercial_invoice_tariffs.each {|t| t.update_attributes! hts_code: nil}
      }

      xml = subject.generate_xml broker_invoice

      # Verify we have a blank Details element
      expect(REXML::XPath.match(xml, "FootLockerInvoice810/Details/Detail").length).to eq 1
      detail = REXML::XPath.match(xml, "FootLockerInvoice810/Details/Detail")[0]
      expect(detail.text("PoNumber")).to eq "0"
      expect(detail.text("Tariff")).to eq "0"
      expect(detail.text("Sku")).to eq "0"
      expect(detail.text("InvoiceNumber")).to eq "0"
    end

    it "sends tariffs even if all data is missing" do
      # blank the PO numbers so we don't generate detail lines
      commercial_invoice.commercial_invoice_lines.each {|ci| 
        ci.update_attributes! po_number: nil, part_number: nil
      }

      xml = subject.generate_xml broker_invoice

      expect(REXML::XPath.match(xml, "FootLockerInvoice810/Details/Detail").length).to eq 1
      detail = REXML::XPath.match(xml, "FootLockerInvoice810/Details/Detail")[0]

      expect(detail.text("PoNumber")).to eq "0"
      expect(detail.text("Tariff")).to eq "1234"
      expect(detail.text("Sku")).to eq "0"
      expect(detail.text("InvoiceNumber")).to eq "COMINV"
    end
  end
end