# encoding: utf-8

require 'spec_helper'

describe OpenChain::CustomHandler::FenixNdInvoiceGenerator do

  def make_address 
    Address.new :line_1 => "123 Fake St.", :line_2 => "Suite 123", :city => "Fakesville", :state => "PA", :postal_code => "12345"
  end

  before :each do
    importer = Factory(:company, :importer=>true, :name=>"Importer", :name_2=>"Division of Importer, Inc.", :addresses=>[make_address], fenix_customer_number: "TAXID")
    vendor = Factory(:company, :vendor=>true, :name=>"Vendor", :addresses=>[make_address])
    consignee = Factory(:company, :consignee=>true, :name=>"Consignee", :addresses=>[make_address])

    @i = Factory(:commercial_invoice, :invoice_number=>"Inv. Number", :invoice_date=>Date.new(2013, 7, 20), :country_origin_code => "US",
                    :currency => "CAD", :total_quantity => 10, :total_quantity_uom => "CTNS", :gross_weight => 100, :invoice_value=>100.10,
                    :importer => importer, :vendor => vendor, :consignee => consignee)

    @entry = Factory(:entry, source_system: "Fenix", importer: importer, customer_number: "CUSTNO")

    @line_1 = Factory(:commercial_invoice_line, :commercial_invoice => @i, :part_number => "ABC", :country_origin_code=>"CN", :quantity=>100, :unit_price=>1, :po_number => "PO NUMBER")
    @line_1.commercial_invoice_tariffs.create :hts_code => "1234567890", :tariff_description=>"Stuff", :tariff_provision => "1"

    @line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @i, :part_number => "DEF", :country_origin_code=>"TW", :quantity=>1, :unit_price=>0.1, :po_number => "PO NUMBER", :customer_reference => "CUSTREF")
    @line_2.commercial_invoice_tariffs.create :hts_code => "09876543210", :tariff_description=>"More Stuff", :tariff_provision => "2"

    @generator = OpenChain::CustomHandler::FenixNdInvoiceGenerator.new
  end

  context :generate_file do

    def verify_company_fields l, i, c
      ranges = [(i..i+49), (i+50..i+99), (i+100..i+149), (i+150..i+199), (i+200..i+249), (i+250..i+299), (i+300..i+349), (i+350..i+399)]

      l[ranges[0]].should == c.name.ljust(50)
      l[ranges[1]].should == c.name_2.to_s.ljust(50)

      a = c.addresses.blank? ? Address.new : c.addresses.first
      l[ranges[2]].should == a.line_1.to_s.ljust(50)
      l[ranges[3]].should == a.line_2.to_s.ljust(50)
      l[ranges[4]].should == a.city.to_s.ljust(50)
      l[ranges[5]].should == a.state.to_s.ljust(50)
      l[ranges[6]].should == a.postal_code.to_s.ljust(50)
    end

    def generate
      contents = nil
      @generator.generate_file(@i.id) do |file|
        contents = file.read.split("\r\n")
      end
      contents
    end

    it "should generate an invoice file" do
      # Tests all the default header / detail mappings
      contents = generate

      contents.length.should == 3
      h = contents[0]
      h[0].should == "H"
      h[1..25].should == @i.invoice_number.ljust(25)
      h[26..35].should == @i.invoice_date.strftime("%Y%m%d").ljust(10)
      h[36..45].should == @i.country_origin_code.ljust(10)
      h[46..55].should == "CA        "
      h[56..59].should == @i.currency.ljust(4)
      h[60..74].should == @i.total_quantity.to_s.ljust(15)
      h[75..89].should == @i.gross_weight.to_s.ljust(15)
      h[90..104].should == @i.commercial_invoice_lines.inject(0.0) {|sum, l| sum + l.quantity}.to_s.ljust(15)
      h[105..119].should == @i.invoice_value.to_s.ljust(15)
      verify_company_fields h, 120, @i.vendor
      verify_company_fields h, 470, @i.consignee
      # Importer data (which is just listed as "GENERIC" in the general case)
      h[820..1169].should == "GENERIC".ljust(350)
      h[1170..1219].should == @i.commercial_invoice_lines.first.po_number.to_s.ljust(50)
      h[1220].should == "2"
      h[1221, 50].should == @line_2.customer_reference.to_s.ljust(50)
      h[1271, 50].should == @i.importer.name.ljust(50)


      @i.commercial_invoice_lines.each_with_index do |l, x|
        t = l.commercial_invoice_tariffs.first

        o = contents[x+1]
        o[0].should == "D"
        o[1..50].should == l.part_number.ljust(50)
        o[51..60].should == l.country_origin_code.ljust(10)
        o[61..72].should == t.hts_code.ljust(12)
        o[73..122].should == t.tariff_description.ljust(50)
        o[123..137].should == l.quantity.to_s.ljust(15)
        o[138..152].should == l.unit_price.to_s.ljust(15)
        o[153..202].should == l.po_number.to_s.ljust(50)
        o[203..212].should == t.tariff_provision.ljust(10)
      end
    end

    it "should use defaults for missing data" do
      # Default output handles missing data in Invoice Number, Cartons, Units, Value, HTS Code, tariff treatment
      @i.update_attributes! invoice_number: nil, total_quantity_uom: nil, invoice_value: nil, gross_weight: nil
      @i.vendor = nil
      @i.consignee = nil
      @i.save!
      @line_1.commercial_invoice_tariffs.first.update_attributes! hts_code: nil, tariff_provision: nil

      contents = generate
      h = contents[0]

      h[1..25].should == "VFI-#{@i.id}".ljust(25)
      # Num Cartons
      h[60..74].should == BigDecimal.new("0").to_s.ljust(15)
      # Gross Weight
      h[75..89].should == "0".ljust(15)
      # It should be poulating the invoice value from the detail level here
      h[105..119].should == BigDecimal.new("100.1").to_s.ljust(15)
      h[120..169].should == "GENERIC".ljust(50)
      h[470..519].should == "GENERIC".ljust(50)
      h[820..869].should == "GENERIC".ljust(50)

      d = contents[1]
      d[61..72].should == "0".ljust(12)
      d[203..212].should == "2".ljust(10)
    end

    it "should not populate units or invoice value if any lines are missing unit counts" do
      @i.update_attributes! invoice_value: nil
      @line_2.update_attributes! quantity: nil

      contents = generate
      contents.length.should == 3
      h = contents[0]

      # Invoice value 
      h[105..119].should == "0.0".ljust(15)
      # Units
      h[90..104].should == "0.0".ljust(15)
    end

    it "should not populate invoice value if any lines are missing unit price" do
      @i.update_attributes! invoice_value: nil
      @line_2.update_attributes! unit_price: nil

      contents = generate
      contents.length.should == 3
      h = contents[0]

      # Invoice value 
      h[105..119].should == "0.0".ljust(15)
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
      contents.length.should == 3
    end

    it "should handle lambdas and constants in mappings" do
      map = @generator.invoice_header_map
      # leave the @generator context off the method call here to ensure the 
      # lambda is executed within the context of the generator

      # Verify the correct parameters were fed to the lambdas too
      l_inv = nil
      map[:invoice_number] = lambda {|h| l_inv = h; ftp_folder}
      map[:invoice_date] = "20130101"

      detail_map = @generator.invoice_detail_map
      dl_inv = []
      dl_line = []
      dl_tar = []

      call_count = 0;
      detail_map[:part_number] = lambda {|h, l, t| dl_inv<< h; dl_line<<l; dl_tar<<t; ftp_folder + (call_count+=1).to_s}

      @generator.should_receive(:invoice_header_map).and_return map
      @generator.should_receive(:invoice_detail_map).and_return detail_map

      contents = generate
      contents.length.should == 3

      contents[0][1..25].should == @generator.ftp_folder.ljust(25)
      contents[0][26..35].should == "20130101".ljust(10)
      contents[1][1..50].should == "#{@generator.ftp_folder}1".ljust(50)
      contents[2][1..50].should == "#{@generator.ftp_folder}2".ljust(50)

      l_inv.should == @i
      dl_inv[0].should == @i
      dl_line[0].should == @i.commercial_invoice_lines.first
      dl_tar[0].should == @i.commercial_invoice_lines.first.commercial_invoice_tariffs.first
      dl_line[1].should == @i.commercial_invoice_lines.second
      dl_tar[1].should == @i.commercial_invoice_lines.second.commercial_invoice_tariffs.first
    end

    it "should error if more than 999 lines are on the invoice" do
      998.times {|x| l = @i.commercial_invoice_lines.build(:part_number=>"#{x}"); l.commercial_invoice_tariffs.build(:hts_code=>"#{x}")}
      
      # THe only reason this is mocked out is to avoid the db save overhead involved with saving an additional 998 (x2) records
      # which ends up being about 20 seconds of time in total
      CommercialInvoice.should_receive(:find).with(@i.id).and_return @i

      expect{generate}.to raise_error "Invoice # #{@i.invoice_number} generated a Fenix invoice file containing 1000 lines.  Invoice's over 999 lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
    end

    it "should transliterate non-ASCII encoding values" do
      @i.invoice_number = "Glósóli"
      @i.save

      contents = generate
      contents.length.should == 3
      h = contents[0]
      h[1..25].should == "Glosoli".ljust(25)
    end

    it "uses ? when it can't transliterate a character" do
      @i.invoice_number = "℗"
      @i.save

      contents = generate
      contents.length.should == 3
      h = contents[0]
      h[1..25].should == "?".ljust(25)
    end

    it "should trim field lengths when they exceed the format's length attribute" do
      @i.invoice_number = "123456789012345678901234567890"
      @i.save

      contents = generate
      contents.length.should == 3
      h = contents[0]
      h[1..25].should == "1234567890123456789012345"
    end

    it "should convert nil hts codes to 0 for output" do 
      # I can't figure out why if I just change a tariff record and save the tariff model directly that the 
      # database value isn't updated..that's the sole reason for destroying and recreating the invoice in the test
      @i.commercial_invoice_lines.destroy_all

      @i.commercial_invoice_lines.create!
      @i.commercial_invoice_lines.first.commercial_invoice_tariffs.create! :hts_code => nil

      contents = generate
      contents.length.should == 2
      h = contents[1]
      h[61..72].should == "0".ljust(12)
    end

    it "strips newlines from values" do
      @i.invoice_number = "Invoice\r1\n2"
      @i.save

      contents = generate
      expect(contents.length).to eq 3
      h = contents[0]
      expect(h[1..25]).to eq "Invoice 1 2".ljust(25)
    end

  end

  context :ftp_credentials do

    it "should use the correct ftp credentials" do
      c = @generator.ftp_credentials
      expect(c).to eq server: "connect.vfitrack.net", username: "www-vfitrack-net", password: "phU^`kN:@T27w.$", folder:nil, protocol: "sftp", port: 2222
    end
  end

  context :generate_and_send do
    it "should generate and ftp the file" do
      file = double("tempfile")
      @generator.should_receive(:generate_file).with(@i.id).and_yield file
      @generator.should_receive(:ftp_file).with(file, folder: "to_ecs/fenix_invoices")

      @generator.generate_and_send @i.id
    end
  end

  describe "generate" do
    it "invokes the generate_and_send instance method" do
      described_class.any_instance.should_receive(:generate_and_send).with 1

      described_class.generate 1
    end
  end
end
