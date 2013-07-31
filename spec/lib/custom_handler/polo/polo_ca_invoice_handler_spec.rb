require 'spec_helper'
require 'digest/sha1'

describe OpenChain::CustomHandler::Polo::PoloCaInvoiceHandler do

  # Excel coordinates are formatted like x, y (ie. col x, row y)
  def default_xl_client_header_values 
    {
      [0, 4]=>Date.new(2013, 7, 15),
      [1, 4]=>"INV Number",
      [7, 4]=>"PO Number",
      [0, 11]=>"US",
      [0, 15]=>"EXW GREENSBORO, NC/CAD",
      [0, 6]=>"Ralph Lauren Corporation",
      [0, 7]=>"4100 Beechwood Drive",
      [0, 8]=>"Greensboro, NC 27410",
      [0, 9]=>"",
      [0, 10]=>"Country of Export",
      [4, 6]=>"Polo Factory Stores - CA",
      [4, 7]=>"Toronto Premium Outlets",
      [4, 8]=>"13850 Steeles Avenue West",
      [4, 9]=>"Halton Hills, Ontario, L7G 0J1",
      [4, 10]=>"",
      [4, 12]=>"Polo Factory Stores",
      [4, 13]=>"a Division of Ralph Lauren Canada, LP",
      [4, 14]=>"2 Queen Street East",
      [4, 15]=>"Suite #801",
      [4, 16]=>"Toronto, Ontario, M5C 3G7"
    }
  end

  def stub_get_cell_calls xl, definitions
    definitions.each {|k, v|
      xl.stub(:get_cell).with(0, k[1], k[0]).and_return v
    }
  end

  def default_xl_client_get_row_values
    {
      15 => [],
      16 => [],
      17 => [],
      18 => [],
      19 => [],
      20 => ["style", "", "hts"],
      21 => ["Style1", "CN", "6106.10.0091", "100% Cotton", "WOMENS", "KNIT", "BSR SOLID PINPOINT SHIRT", 8, 21.14, 169.12],
      # Make the unit price value on the second line a string to verify we handle this occurrance
      22 => ["Style2", "TW", "6106.10.1234", "100% Cotton", "WOMENS", "KNIT", "BSR SOLID SHIRT", 18, "22.14", 380.52],
      23 => ["", "", "", "", "", "", "", "", "", ""],
      24 => ["", "", "", "", "", "units", "", "merchandise total", ""]
    }
  end

  def defaul_xl_client_summary_values starting_row

    {
      [0, (starting_row + 7)] => 809.25,
      [0, (starting_row + 8)] => 20225.50,
      [9, starting_row] => 550.75
    }
  end

  def stub_get_row_calls xl, definitions
    definitions.each {|k, v|
      xl.stub(:get_row_values).with(0, k).and_return v
    }
  end

  def setup_xl_client_stub g, s3_path, header_definitions, summary_definitions,  line_definitions
    xl = double("XLClient")
    g.should_receive(:xl_client).with(s3_path).and_return xl
    stub_get_cell_calls xl, header_definitions
    stub_get_cell_calls xl, summary_definitions
    stub_get_row_calls xl, line_definitions

    xl
  end

  def default_setup generator
    s3_path = "/path/to/file.xls"
    default_rows = default_xl_client_get_row_values
    setup_xl_client_stub generator, s3_path, default_xl_client_header_values, defaul_xl_client_summary_values(default_rows.keys.sort.last), default_rows
    s3_path
  end

  context :parse do

    before :each do
      @importer = Factory(:company, :importer=>true, :fenix_customer_number=>"806167003RM0002")
      @g = described_class.new nil
    end

    it "should use the xl_client to parse an invoice spreadsheet" do
      s3_path = default_setup @g
      @g.parse s3_path, true

      inv = CommercialInvoice.first
      inv.invoice_number.should == "INV Number"
      inv.invoice_date.should == Date.new(2013, 7, 15)
      inv.country_origin_code.should == "US"
      inv.currency.should == "CAD"
      inv.vendor.should_not be_nil
      inv.vendor.name.should == "Ralph Lauren Corporation"
      inv.vendor.name_2.should be_nil
      inv.vendor.addresses.first.name.should == Digest::SHA1.base64digest("Ralph Lauren Corporation".gsub(/\W/, ""))

      inv.consignee.should_not be_nil
      inv.consignee.name.should == "Polo Factory Stores - CA"
      inv.consignee.name_2.should == "Toronto Premium Outlets"
      inv.consignee.addresses.first.name.should == Digest::SHA1.base64digest("Polo Factory Stores - CA Toronto Premium Outlets".gsub(/\W/, ""))

      inv.invoice_value.should == 550.75
      inv.total_quantity.should == 809.25
      inv.total_quantity_uom.should == "CTNS"
      inv.gross_weight.should == 20225

      inv.commercial_invoice_lines.should have(2).items
      l = inv.commercial_invoice_lines.first
      l.part_number.should == "Style1"
      l.country_origin_code.should == "CN"
      l.quantity.should == 8
      l.unit_price.should == 21.14
      l.po_number.should == "PO Number"
      t = l.commercial_invoice_tariffs.first
      t.hts_code.should == "6106100091"
      t.tariff_description.should == "BSR SOLID PINPOINT SHIRT"

      l = inv.commercial_invoice_lines.second
      l.part_number.should == "Style2"
      l.country_origin_code.should == "TW"
      l.quantity.should == 18
      l.unit_price.should == 22.14
      l.po_number.should == "PO Number"
      t = l.commercial_invoice_tariffs.first
      t.hts_code.should == "6106101234"
      t.tariff_description.should == "BSR SOLID SHIRT"
    end

    it "should update an existing invoice and company records" do
      consignee = Factory(:company, :consignee=>true, :name=>"Polo Factory Stores - CA", :name_2=>"Toronto Premium Outlets", :addresses=>[Address.new(:name=>Digest::SHA1.base64digest("Polo Factory Stores - CA Toronto Premium Outlets".gsub(/\W/, "")))])
      @importer.linked_companies << consignee
      vendor = Factory(:company, :vendor=>true, :name=>"Ralph Lauren Corporation", :addresses=>[Address.new(:name=>Digest::SHA1.base64digest("RalphLaurenCorporation"))])
      @importer.linked_companies << vendor
      inv = Factory(:commercial_invoice, :invoice_number=>"INV Number", :importer=>@importer, :consignee=>consignee, :vendor=>vendor)

      s3_path = default_setup @g
      @g.parse s3_path, true

      i = CommercialInvoice.where(:invoice_number=>"INV Number", :importer_id=>@importer.id).first
      i.should_not be_nil

      #make sure we actaully got some updated information..
      i.commercial_invoice_lines.should have(2).items
      i.consignee.id.should == consignee.id
      i.vendor.id.should == vendor.id
    end

    it "should handle multiple hts numbers in the same cell" do
      # If we get multiple hts #'s we're going to not grab any of them since the data is for
      # individual components of a set and we don't know which one should be used (why we're getting these is another question entirely)
      s3_path = "/path/to/file.xls"
      default_rows = default_xl_client_get_row_values
      default_rows[21][2] = "Dress: 1234.56.7890 / Leopard Skin Pillbox Hat: 9876.54.3210"
      setup_xl_client_stub @g, s3_path, default_xl_client_header_values, defaul_xl_client_summary_values(default_rows.keys.sort.last), default_rows

      @g.parse s3_path, true
      i = CommercialInvoice.where(:invoice_number=>"INV Number", :importer_id=>@importer.id).first
      i.should_not be_nil
      i.commercial_invoice_lines.should have(2).items

      i.commercial_invoice_lines.first.commercial_invoice_tariffs.first.hts_code.should be_nil
    end

    it "should handle missing importer" do
      @importer.destroy
      expect{@g.parse nil, true}.to raise_error "No Importer company exists with Tax ID 806167003RM0002.  This company must exist before RL CA invoices can be created against it."
    end

    it "should send to invoice generator if instructed" do
      inv = Factory(:commercial_invoice, :invoice_number=>"INV Number", :importer=>@importer)
      s3_path = default_setup @g
      OpenChain::CustomHandler::Polo::PoloCaFenixInvoiceGenerator.should_receive(:generate).with inv.id
      @g.parse s3_path
    end

    it "should handle not finding invoice line starting position prior to row 25" do
      s3_path = "/path/to/file.xls"
      default_rows = {
        15 => [],
        16 => [],
        17 => [],
        18 => [],
        19 => [],
        20 => [],
        21 => [],
        22 => [],
        23 => [],
        24 => [],
        25=>[]
      }

      setup_xl_client_stub @g, s3_path, default_xl_client_header_values,defaul_xl_client_summary_values(default_rows.keys.sort.last), default_rows
      expect{@g.parse s3_path, true}.to raise_error 'Unable to locate where invoice detail lines begin.  Detail lines should begin after a header in Column A named "HTS" and a header in Column B named "Country of Origin".'
    end
  end

  context :can_view? do

    it "should allow master users to view" do
      described_class.new(nil).can_view?(Factory(:master_user)).should be_true
    end

    it "should not allow other users to view" do
      described_class.new(nil).can_view?(Factory(:user)).should be_false
    end
  end

  context :process do

    it "should process the custom file using it's s3 path" do
      custom_file = double("CustomFile")
      custom_file.should_receive(:attached).and_return custom_file
      custom_file.should_receive(:path).and_return "s3_path"
      custom_file.should_receive(:attached_file_name).and_return "file.xls"

      user = Factory(:master_user)

      g =  described_class.new(custom_file)
      g.should_receive(:parse).with("s3_path")
      g.process user

      user.messages.should have(1).item
      m = user.messages.first
      m.subject.should == "RL Canada Invoice File Processing Complete"
      m.body.should == "RL Canada Invoice File 'file.xls' has finished processing."
    end

    it "should process the custom file and handle errors" do
      custom_file = double("CustomFile")
      custom_file.should_receive(:attached).and_return custom_file
      custom_file.should_receive(:path).and_return "s3_path"
      custom_file.should_receive(:attached_file_name).and_return "file.xls"

      user = Factory(:master_user)

      g =  described_class.new(custom_file)
      g.should_receive(:parse).with("s3_path").and_raise "Error!!"
      expect{g.process user}.to raise_error "Error!!"

      user.messages.should have(1).item
      m = user.messages.first
      m.subject.should == "RL Canada Invoice File Processing Complete"
      m.body.should == "RL Canada Invoice File 'file.xls' has finished processing.\nErrors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
    end
  end
  
end