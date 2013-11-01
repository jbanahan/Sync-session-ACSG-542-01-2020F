require 'spec_helper'

describe OpenChain::CustomHandler::Crocs::CrocsReceivingParser do
  before :each do 
    @s3_path = 'abc'
    @xl_client = double('xl_client')
    OpenChain::XLClient.stub(:new).and_return @xl_client
  end
  describe :validate_s3 do
    before :each do 
    end
    it "should validate headers" do
      good_headers = [
        'SHPMT_NBR',
        'PO_NBR',
        'SKU_BRCD',
        'STYLE',
        'COLOR',
        'SIZ',
        'SKU_DESC',
        'CNTRY_OF_ORGN',
        'UNITS_RCVD',
        'RCVD_DATE',
        'UOM'
      ]
      @xl_client.should_receive(:get_row_values).with(0,0).and_return good_headers
      described_class.validate_s3(@s3_path).should be_empty
    end
    it "should error if first row doesn't match" do
      bad_headers = [
        'S_NBR',
        'PO_NBR',
        'SKU_BRCD',
        'STYLE',
        'COLOR',
        'SIZ',
        'SKU_DESC',
        'CNTRY_OF_ORGN',
        'UNITS_RCVD',
      ]
      @xl_client.should_receive(:get_row_values).with(0,0).and_return bad_headers
      described_class.validate_s3(@s3_path).should == [
        'Heading at position 1 should be SHPMT_NBR and was S_NBR.',
        'Heading at position 10 should be RCVD_DATE and was blank.'
      ]
    end
  end

  describe :parse_s3 do
    it "should call parse_shipment with arrays of rows" do
      described_class.should_receive(:validate_s3).with(@s3_path).and_return []
      @xl_client.should_receive(:all_row_values).with(0).
        and_yield(['HEADING']).
        and_yield(['1','','','','','','','','',Date.new(2013,1,1)]).
        and_yield(['1','','','','','','','','',Date.new(2011,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2012,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2010,1,1)])
      described_class.any_instance.should_receive(:parse_shipment).with([['1','','','','','','','','',Date.new(2013,1,1)],['1','','','','','','','','',Date.new(2011,1,1)]])
      described_class.any_instance.should_receive(:parse_shipment).with([['2','','','','','','','','',Date.new(2012,1,1)],['2','','','','','','','','',Date.new(2010,1,1)]])
      described_class.parse_s3 @s3_path
    end
    it "should return earliest and latest received dates" do
      described_class.should_receive(:validate_s3).with(@s3_path).and_return []
      @xl_client.should_receive(:all_row_values).with(0).
        and_yield(['HEADING']).
        and_yield(['1','','','','','','','','',Date.new(2013,1,1)]).
        and_yield(['1','','','','','','','','',Date.new(2011,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2012,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2010,1,1)])
      described_class.any_instance.stub(:parse_shipment)
      described_class.parse_s3(@s3_path).should == [Date.new(2010,1,1),Date.new(2013,1,1)]
    end
  end

  describe :parse_shipment do
    before :each do 
      @importer = Factory(:company,importer:true,alliance_customer_number:'CROCS')
    end
    it "should create a new shipment" do
      rows = [
        ['1','PO1','SKU1','STY1','COL1','SIZE1','DESC1','CN',10,Time.now.to_date],
        ['1','PO1','SKU2','STY1','COL2','SIZE2','DESC2','CN',11,Time.now.to_date],
        ['1','PO1','SKU3','STY1','COL1','SIZE1','DESC1','CN',12,Time.now.to_date],
        ['1','PO1','SKU4','STY2','COL1','SIZE1','DESC1','CN',13,Time.now.to_date],
        ['1','PO1','SKU5','STY2','COL1','SIZE1','DESC1','CN',14,Time.now.to_date],
        ['1','PO1','SKU6','STY2','COL1','SIZE1','DESC1','CN',15,Time.now.to_date]
      ]
      described_class.new.parse_shipment rows
      
      #run this after the call to parse shipment to make sure it doesn't create a false positive if parse shipment improperly preps custom definitions
      defs = described_class.prep_custom_definitions [:shpln_po,:shpln_sku,:shpln_color,:shpln_size,:shpln_coo,:shpln_received_date]

      Product.all.size.should == 2
      style1 = Product.find_by_unique_identifier('CROCS-STY1')
      style1.should_not be_nil
      style2 = Product.find_by_unique_identifier('CROCS-STY2')
      style2.should_not be_nil
      s = Shipment.first
      s.importer.should == @importer
      s.reference.should == 'CROCS-1'
      s.should have(6).shipment_lines
      sl1 = s.shipment_lines.find_by_line_number(1)
      sl1.quantity.should == 10
      sl1.product.should == style1
      sl1.get_custom_value(defs[:shpln_po]).value.should == 'PO1'
      sl1.get_custom_value(defs[:shpln_sku]).value.should == 'SKU1'
      sl1.get_custom_value(defs[:shpln_color]).value.should == 'COL1'
      sl1.get_custom_value(defs[:shpln_size]).value.should == 'SIZE1'
      sl1.get_custom_value(defs[:shpln_coo]).value.should == 'CN'
      sl1.get_custom_value(defs[:shpln_received_date]).value.to_date.should == Time.now.to_date 
      
      sl2 = s.shipment_lines.find_by_line_number(2)
      sl2.quantity.should == 11
      sl2.product.should == style1
      sl2.get_custom_value(defs[:shpln_po]).value.should == 'PO1'
      sl2.get_custom_value(defs[:shpln_sku]).value.should == 'SKU2'
      sl2.get_custom_value(defs[:shpln_color]).value.should == 'COL2'
      sl2.get_custom_value(defs[:shpln_size]).value.should == 'SIZE2'
      sl2.get_custom_value(defs[:shpln_coo]).value.should == 'CN'
      sl2.get_custom_value(defs[:shpln_received_date]).value.to_date.should == Time.now.to_date 
    end
    it "should merge like rows in same shipment" do
      rows = [
        ['1','PO1','SKU1','STY1','COL1','SIZE1','DESC1','CN',10,Time.now.to_date],
        ['1','PO1','SKU1','STY1','COL1','SIZE1','DESC1','CN',10,Time.now.to_date]
      ]
      #this one should be ok
      described_class.new.parse_shipment rows
      ShipmentLine.first.quantity.should == 20
    end
    it "should fail if shipment / po / sku / received date / coo already exists" do
      rows = [
        ['1','PO1','SKU1','STY1','COL1','SIZE1','DESC1','CN',10,Time.now.to_date]
      ]
      #this one should be ok
      described_class.new.parse_shipment rows

      lambda {
        described_class.new.parse_shipment rows
      }.should raise_error "Duplicate receipts CROCS-1, PO1, SKU1, #{Time.now.to_date.to_s}, CN"
    end
  end

end
