require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourFtzParser do

  before :each do
    @line = "1600,113-4873420-0,85075306,1200739-001,7,285,ID,6402992760,892.05,26.7615,0.03,0,0,UA LOCKER SLIDE - BLK/SLV" 
    @port_code = "1303"
    @box_37 = 100
    @box_40 = 101
    @total_value = 102
    @total_mpf = 103
    @entered_date = 1.day.ago
    @parser = described_class.new(@total_value, @total_mpf,
      @entered_date, @port_code, @box_37, @box_40)
  end

  it "should match to existing export line and create import line" do
    exp = Factory(:duty_calc_export_file_line,:ref_1=>'85075306')
    t = Tempfile.new("ftz")
    t << @line
    t.flush
    @parser.process_csv t.path
    Product.first.unique_identifier.should == "1200739-001"
    DrawbackImportLine.all.should have(1).item
    d = DrawbackImportLine.first
    d.product.should == Product.first
    d.entry_number.should == "11348734200"
    d.import_date.strftime("%m/%d/%Y").should == @entered_date.strftime("%m/%d/%Y")
    d.received_date.strftime("%m/%d/%Y").should == @entered_date.strftime("%m/%d/%Y")
    d.port_code.should == @port_code
    d.box_37_duty.should == @box_37
    d.box_40_duty.should == @box_40
    d.total_invoice_value.should == @total_value
    d.total_mpf.should == @total_mpf
    d.country_of_origin_code.should == "ID"
    d.part_number.should == "1200739-001-7+ID"
    d.hts_code.should == "6402992760"
    d.description.should == "UA LOCKER SLIDE - BLK/SLV"
    d.unit_of_measure.should == "EA"
    d.quantity.should == 285
    d.unit_price.should == 3.13
    d.rate.should == 0.03
    d.duty_per_unit.should == 0.0939
  end
  it "should not create import lines if they already exist" do
    exp = Factory(:duty_calc_export_file_line,:ref_1=>'85075306')
    t = Tempfile.new("ftz")
    t << @line
    t.flush
    @parser.process_csv t.path
    @parser.process_csv t.path
    DrawbackImportLine.all.should have(1).item
  end
  it "should not create import lines if export lines don't already exist" do
    t = Tempfile.new("ftz")
    t << @line
    t.flush
    @parser.process_csv t.path
    DrawbackImportLine.all.should be_empty
    Product.all.should be_empty
  end

end
