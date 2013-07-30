# encoding: utf-8

require 'spec_helper'

describe OpenChain::CustomHandler::FenixInvoiceGenerator do

  def make_address 
    Address.new :line_1 => "123 Fake St.", :line_2 => "Suite 123", :city => "Fakesville", :state => "PA", :postal_code => "12345"
  end

  before :each do
    importer = Factory(:company, :importer=>true, :name=>"Importer", :name_2=>"Division of Importer, Inc.", :addresses=>[make_address])
    vendor = Factory(:company, :vendor=>true, :name=>"Vendor", :addresses=>[make_address])
    consignee = Factory(:company, :consignee=>true, :name=>"Consignee", :addresses=>[make_address])

    @i = Factory(:commercial_invoice, :invoice_number=>"Inv. Number", :invoice_date=>Date.new(2013, 7, 20), :country_origin_code => "US",
                    :currency => "CAD", :total_quantity => 10, :total_quantity_uom => "CTNS", :gross_weight => 100, :invoice_value=>100.10,
                    :importer => importer, :vendor => vendor, :consignee => consignee)

    @line_1 = Factory(:commercial_invoice_line, :commercial_invoice => @i, :part_number => "ABC", :country_origin_code=>"CN", :quantity=>100, :unit_price=>1, :po_number => "PO NUMBER")
    @line_1.commercial_invoice_tariffs << CommercialInvoiceTariff.new(:hts_code => "1234567890", :tariff_description=>"Stuff")
    @line_2 = Factory(:commercial_invoice_line, :commercial_invoice => @i, :part_number => "DEF", :country_origin_code=>"TW", :quantity=>1, :unit_price=>0.1, :po_number => "PO NUMBER")
    @line_2.commercial_invoice_tariffs << CommercialInvoiceTariff.new(:hts_code => "09876543210", :tariff_description=>"More Stuff")

    base = Class.new do
      include OpenChain::CustomHandler::FenixInvoiceGenerator
      def invoice_header_map; default_invoice_header_map; end
      def invoice_detail_map; default_invoice_detail_map; end
      def fenix_customer_code; "FENIX_CUST"; end
    end

    @generator = base.new
  end

  context :generate_file do

    after :each do
      @f.close! if @f
    end

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

    it "should generate an invoice file" do
      @f = @generator.generate_file @i.id
      @f.rewind
      contents = @f.read.split("\r\n")
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
      verify_company_fields h, 820, @i.importer
      h[1170..1219].should == @i.commercial_invoice_lines.first.po_number.to_s.ljust(50)
      h[1220].should == "2"


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
      end
    end

    it "should handle nils in all default field values" do
      # Just make sure it doesn't blow up with nil values in every field
      importer = Factory(:company, :importer=>true, :addresses=>[Address.new])
      vendor = Factory(:company, :vendor=>true, :addresses=>[Address.new])
      consignee = Factory(:company, :consignee=>true, :addresses=>[Address.new])

      i = Factory(:commercial_invoice, :importer => importer, :vendor => vendor, :consignee => consignee)
      l1 = Factory(:commercial_invoice_line, :commercial_invoice => i)
      l1.commercial_invoice_tariffs << CommercialInvoiceTariff.new

      @f = @generator.generate_file @i.id
      @f.rewind
      contents = @f.read.split("\r\n")
      contents.length.should == 3
    end

    it "should handle lambdas and constants in mappings" do
      map = @generator.default_invoice_header_map
      # leave the @generator context off the method call here to ensure the 
      # lambda is executed within the context of the generator

      # Verify the correct parameters were fed to the lambdas too
      l_inv = nil
      map[:invoice_number] = lambda {|h| l_inv = h; fenix_customer_code()}
      map[:invoice_date] = "20130101"

      detail_map = @generator.invoice_detail_map
      dl_inv = []
      dl_line = []
      dl_tar = []

      call_count = 0;
      detail_map[:part_number] = lambda {|h, l, t| dl_inv<< h; dl_line<<l; dl_tar<<t; fenix_customer_code() + (call_count+=1).to_s}

      @generator.should_receive(:default_invoice_header_map).and_return map
      @generator.should_receive(:default_invoice_detail_map).and_return detail_map

      @f = @generator.generate_file @i.id
      @f.rewind
      contents = @f.read.split("\r\n")
      contents.length.should == 3

      contents[0][1..25].should == @generator.fenix_customer_code.ljust(25)
      contents[0][26..35].should == "20130101".ljust(10)
      contents[1][1..50].should == "#{@generator.fenix_customer_code}1".ljust(50)
      contents[2][1..50].should == "#{@generator.fenix_customer_code}2".ljust(50)

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

      expect{@generator.generate_file(@i.id)}.to raise_error "Invoice # #{@i.invoice_number} generated a Fenix invoice file containing 1000 lines.  Invoice's over 999 lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
    end

    it "should handle non-ASCII encoding values and translate them to '?' when outputting" do
      @i.invoice_number = "Glósóli"
      @i.save

      @f = @generator.generate_file @i.id
      @f.rewind
      contents = @f.read.split("\r\n")
      contents.length.should == 3
      h = contents[0]
      h[1..25].should == "Gl?s?li".ljust(25)

    end

    it "should trim field lengths when they exceed the format's length attribute" do
      @i.invoice_number = "123456789012345678901234567890"
      @i.save

      @f = @generator.generate_file @i.id
      @f.rewind
      contents = @f.read.split("\r\n")
      contents.length.should == 3
      h = contents[0]
      h[1..25].should == "1234567890123456789012345"
    end
  end

  context :ftp_credentials do

    it "should use the correct ftp credentials" do
      c = @generator.ftp_credentials
      c[:server].should == "ftp2.vandegriftinc.com"
      c[:username].should == "VFITRack"
      c[:password].should == "RL2VFftp"
      c[:folder].should == "/to_ecs/fenix_invoices"
      c[:remote_file_name].should =~ /^FENIX_CUST_INV_\d+\.txt$/
    end
  end

  context :generate_and_send do

    it "should generate and ftp the file" do
      file = double("tempfile")
      @generator.should_receive(:generate_file).with(@i.id).and_return file
      @generator.should_receive(:ftp_file).with(file)

      @generator.generate_and_send @i.id
    end

    it "should not attempt to send a nil file" do
      @generator.should_receive(:generate_file).with(@i.id).and_return nil
      @generator.should_not_receive(:ftp_file)
      @generator.generate_and_send @i.id
    end
  end
end