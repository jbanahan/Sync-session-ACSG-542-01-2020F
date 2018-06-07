# encoding: utf-8

require 'spec_helper'

describe OpenChain::CustomHandler::FenixNdInvoiceGenerator do

  def make_address 
    Address.new :line_1 => "123 Fake St.", :line_2 => "Suite 123", :city => "Fakesville", :state => "PA", :postal_code => "12345"
  end

  let (:importer) { 
    Factory(:company, :importer=>true, :name=>"Importer", :name_2=>"Division of Importer, Inc.", :addresses=>[make_address], fenix_customer_number: "TAXID")
  }

  let (:vendor) {
    Factory(:company, :vendor=>true, :name=>"Vendor", :addresses=>[make_address])
  }

  let (:consignee) {
    Factory(:company, :consignee=>true, :name=>"Consignee", :addresses=>[make_address])
  }

  let! (:invoice) {
    Factory(:commercial_invoice, :invoice_number=>"Inv. Number", :invoice_date=>Date.new(2013, 7, 20), :country_origin_code => "US",
                      :currency => "CAD", :total_quantity => 10, :total_quantity_uom => "CTNS", :gross_weight => 100, :invoice_value=>100.10,
                      :importer => importer, :vendor => vendor, :consignee => consignee, master_bills_of_lading: "SCAC1234567890")    
  }

  let! (:invoice_line_1) {
    line = Factory(:commercial_invoice_line, :commercial_invoice => invoice, :part_number => "ABC", :country_origin_code=>"CN", :quantity=>100, :unit_price=>1, :po_number => "PO NUMBER")
    line.commercial_invoice_tariffs.create :hts_code => "1234567890", :tariff_description=>"Stuff", :tariff_provision => "1"
    line
  }

  let! (:invoice_line_2) {
    line = Factory(:commercial_invoice_line, :commercial_invoice => invoice, :part_number => "DEF", :country_origin_code=>"TW", :quantity=>1, :unit_price=>0.1, :po_number => "PO NUMBER", :customer_reference => "CUSTREF")
    line.commercial_invoice_tariffs.create :hts_code => "09876543210", :tariff_description=>"More Stuff", :tariff_provision => "2"
    line
  }

  context "generate_file" do

    def verify_company_fields l, i, c
      ranges = [(i..i+49), (i+50..i+99), (i+100..i+149), (i+150..i+199), (i+200..i+249), (i+250..i+299), (i+300..i+349), (i+350..i+399)]

      expect(l[ranges[0]]).to eq(c.name.ljust(50))
      expect(l[ranges[1]]).to eq(c.name_2.to_s.ljust(50))

      a = c.addresses.blank? ? Address.new : c.addresses.first
      expect(l[ranges[2]]).to eq(a.line_1.to_s.ljust(50))
      expect(l[ranges[3]]).to eq(a.line_2.to_s.ljust(50))
      expect(l[ranges[4]]).to eq(a.city.to_s.ljust(50))
      expect(l[ranges[5]]).to eq(a.state.to_s.ljust(50))
      expect(l[ranges[6]]).to eq(a.postal_code.to_s.ljust(50))
    end

    def generate
      contents = nil
      subject.generate_file(invoice) do |file|
        contents = file.read.split("\r\n")
      end
      contents
    end

    it "should generate an invoice file" do
      # Tests all the default header / detail mappings
      contents = generate

      expect(contents.length).to eq(3)
      h = contents[0]
      expect(h[0]).to eq("H")
      expect(h[1..25]).to eq(invoice.invoice_number.ljust(25))
      expect(h[26..35]).to eq(invoice.invoice_date.strftime("%Y%m%d").ljust(10))
      expect(h[36..45]).to eq(invoice.country_origin_code.ljust(10))
      expect(h[46..55]).to eq("CA        ")
      expect(h[56..59]).to eq(invoice.currency.ljust(4))
      expect(h[60..74]).to eq(invoice.total_quantity.to_s.ljust(15))
      expect(h[75..89]).to eq(invoice.gross_weight.to_s.ljust(15))
      expect(h[90..104]).to eq(invoice.commercial_invoice_lines.inject(0.0) {|sum, l| sum + l.quantity}.to_s.ljust(15))
      expect(h[105..119]).to eq(invoice.invoice_value.to_s.ljust(15))
      verify_company_fields h, 120, invoice.vendor
      verify_company_fields h, 470, invoice.consignee
      # Importer data (which is just listed as "GENERIC" in the general case)
      expect(h[820..1169]).to eq("GENERIC".ljust(350))
      expect(h[1170..1219]).to eq(invoice.commercial_invoice_lines.first.po_number.to_s.ljust(50))
      expect(h[1220]).to eq("2")
      expect(h[1221, 50]).to eq(invoice_line_2.customer_reference.to_s.ljust(50))
      expect(h[1271, 50]).to eq(invoice.importer.name.ljust(50))
      expect(h[1321, 4]).to eq "SCAC"
      expect(h[1325, 30]).to eq "SCAC1234567890                "


      invoice.commercial_invoice_lines.each_with_index do |l, x|
        t = l.commercial_invoice_tariffs.first

        o = contents[x+1]
        expect(o[0]).to eq("D")
        expect(o[1..50]).to eq(l.part_number.ljust(50))
        expect(o[51..60]).to eq(l.country_origin_code.ljust(10))
        expect(o[61..72]).to eq(t.hts_code.ljust(12))
        expect(o[73..122]).to eq(t.tariff_description.ljust(50))
        expect(o[123..137]).to eq(l.quantity.to_s.ljust(15))
        expect(o[138..152]).to eq(l.unit_price.to_s.ljust(15))
        expect(o[153..202]).to eq(l.po_number.to_s.ljust(50))
        expect(o[203..212]).to eq(t.tariff_provision.ljust(10))
      end
    end

    it "does not fail with invoices containing slashes in the name" do
      invoice.update_attributes! invoice_number: "INV/2"
      contents = generate

      expect(contents.length).to eq(3)
    end

    it "should use defaults for missing data" do
      # Default output handles missing data in Invoice Number, Cartons, Units, Value, HTS Code, tariff treatment
      invoice.update_attributes! invoice_number: nil, total_quantity_uom: nil, invoice_value: nil, gross_weight: nil
      invoice.vendor = nil
      invoice.consignee = nil
      invoice.save!
      invoice_line_1.commercial_invoice_tariffs.first.update_attributes! hts_code: nil, tariff_provision: nil

      contents = generate
      h = contents[0]

      expect(h[1..25]).to eq("VFI-#{invoice.id}".ljust(25))
      # Num Cartons
      expect(h[60..74]).to eq(BigDecimal.new("0").to_s.ljust(15))
      # Gross Weight
      expect(h[75..89]).to eq("0".ljust(15))
      # It should be poulating the invoice value from the detail level here
      expect(h[105..119]).to eq(BigDecimal.new("100.1").to_s.ljust(15))
      expect(h[120..169]).to eq("GENERIC".ljust(50))
      expect(h[470..519]).to eq("GENERIC".ljust(50))
      expect(h[820..869]).to eq("GENERIC".ljust(50))

      d = contents[1]
      expect(d[61..72]).to eq("0".ljust(12))
      expect(d[203..212]).to eq("2".ljust(10))
    end

    it "should not populate units or invoice value if any lines are missing unit counts" do
      invoice.update_attributes! invoice_value: nil
      invoice_line_2.update_attributes! quantity: nil

      contents = generate
      expect(contents.length).to eq(3)
      h = contents[0]

      # Invoice value 
      expect(h[105..119]).to eq("0.0".ljust(15))
      # Units
      expect(h[90..104]).to eq("0.0".ljust(15))
    end

    it "should not populate invoice value if any lines are missing unit price" do
      invoice.update_attributes! invoice_value: nil
      invoice_line_2.update_attributes! unit_price: nil

      contents = generate
      expect(contents.length).to eq(3)
      h = contents[0]

      # Invoice value 
      expect(h[105..119]).to eq("0.0".ljust(15))
    end

    it "should handle nils in all default field values" do
      # Just make sure it doesn't blow up with nil values in every field
      importer = Factory(:company, :importer=>true, :addresses=>[Address.new])
      vendor = Factory(:company, :vendor=>true, :addresses=>[Address.new])
      consignee = Factory(:company, :consignee=>true, :addresses=>[Address.new])

      i = Factory(:commercial_invoice, :importer => importer, :vendor => vendor, :consignee => consignee)
      l1 = Factory(:commercial_invoice_line, :commercial_invoice => i)
      l1.commercial_invoice_tariffs << CommercialInvoiceTariff.new

      contents = generate
      expect(contents.length).to eq(3)
    end

    it "should handle lambdas and constants in mappings" do
      map = subject.invoice_header_map
      # leave the subject context off the method call here to ensure the 
      # lambda is executed within the context of the generator

      # Verify the correct parameters were fed to the lambdas too
      l_inv = nil
      map[:invoice_number] = lambda {|h| l_inv = h; ftp_folder}
      map[:invoice_date] = "20130101"

      detail_map = subject.invoice_detail_map
      dl_inv = []
      dl_line = []
      dl_tar = []

      call_count = 0;
      detail_map[:part_number] = lambda {|h, l, t| dl_inv<< h; dl_line<<l; dl_tar<<t; ftp_folder + (call_count+=1).to_s}

      expect(subject).to receive(:invoice_header_map).and_return map
      expect(subject).to receive(:invoice_detail_map).and_return detail_map

      contents = generate
      expect(contents.length).to eq(3)

      expect(contents[0][1..25]).to eq(subject.ftp_folder.ljust(25))
      expect(contents[0][26..35]).to eq("20130101".ljust(10))
      expect(contents[1][1..50]).to eq("#{subject.ftp_folder}1".ljust(50))
      expect(contents[2][1..50]).to eq("#{subject.ftp_folder}2".ljust(50))

      expect(l_inv).to eq(invoice)
      expect(dl_inv[0]).to eq(invoice)
      expect(dl_line[0]).to eq(invoice.commercial_invoice_lines.first)
      expect(dl_tar[0]).to eq(invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.first)
      expect(dl_line[1]).to eq(invoice.commercial_invoice_lines.second)
      expect(dl_tar[1]).to eq(invoice.commercial_invoice_lines.second.commercial_invoice_tariffs.first)
    end

    it "should error if more than 999 lines are on the invoice" do
      998.times {|x| l = invoice.commercial_invoice_lines.build(:part_number=>"#{x}"); l.commercial_invoice_tariffs.build(:hts_code=>"#{x}")}
      
      expect{generate}.to raise_error "Invoice # #{invoice.invoice_number} generated a Fenix invoice file containing 1000 lines.  Invoice's over 999 lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
    end

    it "should transliterate non-ASCII encoding values" do
      invoice.invoice_number = "Glósóli"
      invoice.save

      contents = generate
      expect(contents.length).to eq(3)
      h = contents[0]
      expect(h[1..25]).to eq("Glosoli".ljust(25))
    end

    it "uses ? when it can't transliterate a character" do
      invoice.invoice_number = "℗"
      invoice.save

      contents = generate
      expect(contents.length).to eq(3)
      h = contents[0]
      expect(h[1..25]).to eq("?".ljust(25))
    end

    it "should trim field lengths when they exceed the format's length attribute" do
      invoice.invoice_number = "123456789012345678901234567890"
      invoice.save

      contents = generate
      expect(contents.length).to eq(3)
      h = contents[0]
      expect(h[1..25]).to eq("1234567890123456789012345")
    end

    it "should convert nil hts codes to 0 for output" do 
      # I can't figure out why if I just change a tariff record and save the tariff model directly that the 
      # database value isn't updated..that's the sole reason for destroying and recreating the invoice in the test
      invoice.commercial_invoice_lines.destroy_all

      invoice.commercial_invoice_lines.create!
      invoice.commercial_invoice_lines.first.commercial_invoice_tariffs.create! :hts_code => nil

      contents = generate
      expect(contents.length).to eq(2)
      h = contents[1]
      expect(h[61..72]).to eq("0".ljust(12))
    end

    it "strips newlines from values" do
      invoice.invoice_number = "Invoice\r1\n2"
      invoice.save

      contents = generate
      expect(contents.length).to eq 3
      h = contents[0]
      expect(h[1..25]).to eq "Invoice 1 2".ljust(25)
    end

    it "strips ! and | from values" do
      invoice.invoice_number = "Invoice!1|2"
      invoice.save

      contents = generate
      expect(contents.length).to eq 3
      h = contents[0]
      expect(h[1..25]).to eq "Invoice 1 2".ljust(25)
    end

    it "can receive an invoice id" do
      contents = nil
      subject.generate_file(invoice.id) do |file|
        contents = file.read.split("\r\n")
      end
      contents
      # just check that there's contents.
      expect(contents.length).to eq 3
    end

    it "sends default message for blank master bills" do
      invoice.master_bills_of_lading = nil

      contents = generate
      header = contents[0]
      expect(header[1321, 4]).to eq "    "
      expect(header[1325, 30]).to eq "Not Available                 "
    end
  end

  context "ftp_connection_info" do
    it "should use the correct ftp credentials" do
      expect(subject).to receive(:connect_vfitrack_net).with("to_ecs/fenix_invoices")
      subject.ftp_connection_info
    end
  end

  context "generate_and_send" do
    it "should generate and ftp the file" do
      file = double("tempfile")
      expect(subject).to receive(:generate_file).with(invoice.id).and_yield file
      expect(subject).to receive(:ftp_file).with(file, subject.ftp_connection_info)

      subject.generate_and_send invoice.id
    end

    it "allows passing sync record" do
      sr = SyncRecord.new

      file = double("tempfile")
      expect(subject).to receive(:generate_file).with(invoice).and_yield file
      expect(subject).to receive(:ftp_sync_file).with(file, sr, subject.ftp_connection_info)

      subject.generate_and_send invoice, sync_record: sr
    end
  end

  describe "generate" do
    it "invokes the generate_and_send instance method" do
      expect_any_instance_of(described_class).to receive(:generate_and_send).with 1

      described_class.generate 1
    end
  end
end
