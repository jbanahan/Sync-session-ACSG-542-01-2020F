describe OpenChain::CustomHandler::Crocs::CrocsReceivingParser do
  before :each do 
    @s3_path = 'abc'
    @xl_client = double('xl_client')
    allow(OpenChain::XLClient).to receive(:new).and_return @xl_client
  end
  describe "validate_s3" do
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
      expect(@xl_client).to receive(:get_row_values).with(0,0).and_return good_headers
      expect(described_class.validate_s3(@s3_path)).to be_empty
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
      expect(@xl_client).to receive(:get_row_values).with(0,0).and_return bad_headers
      expect(described_class.validate_s3(@s3_path)).to eq([
        'Heading at position 1 should be SHPMT_NBR and was S_NBR.',
        'Heading at position 10 should be RCVD_DATE and was blank.'
      ])
    end
  end

  describe "parse_s3" do
    it "should call parse_shipment with arrays of rows" do
      expect(described_class).to receive(:validate_s3).with(@s3_path).and_return []
      expect(@xl_client).to receive(:all_row_values).
        and_yield(['HEADING']).
        and_yield(['1','','','','','','','','',Date.new(2013,1,1)]).
        and_yield(['1','','','','','','','','',Date.new(2011,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2012,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2010,1,1)])
      expect_any_instance_of(described_class).to receive(:parse_shipment).with([['1','','','','','','','','',Date.new(2013,1,1)],['1','','','','','','','','',Date.new(2011,1,1)]])
      expect_any_instance_of(described_class).to receive(:parse_shipment).with([['2','','','','','','','','',Date.new(2012,1,1)],['2','','','','','','','','',Date.new(2010,1,1)]])
      described_class.parse_s3 @s3_path
    end
    it "should return earliest and latest received dates" do
      expect(described_class).to receive(:validate_s3).with(@s3_path).and_return []
      expect(@xl_client).to receive(:all_row_values).
        and_yield(['HEADING']).
        and_yield(['1','','','','','','','','',Date.new(2013,1,1)]).
        and_yield(['1','','','','','','','','',Date.new(2011,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2012,1,1)]).
        and_yield(['2','','','','','','','','',Date.new(2010,1,1)])
      allow_any_instance_of(described_class).to receive(:parse_shipment)
      expect(described_class.parse_s3(@s3_path)).to eq([Date.new(2010,1,1),Date.new(2013,1,1)])
    end
  end

  describe "parse_shipment" do
    before :each do 
      @importer = with_customs_management_id(Factory(:company,importer:true), 'CROCS')
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

      expect(Product.all.size).to eq(2)
      style1 = Product.find_by(unique_identifier: 'CROCS-STY1')
      expect(style1).not_to be_nil
      style2 = Product.find_by(unique_identifier: 'CROCS-STY2')
      expect(style2).not_to be_nil
      s = Shipment.first
      expect(s.importer).to eq(@importer)
      expect(s.reference).to eq('CROCS-1')
      expect(s.shipment_lines.size).to eq(6)
      sl1 = s.shipment_lines.find_by(line_number: 1)
      expect(sl1.quantity).to eq(10)
      expect(sl1.product).to eq(style1)
      expect(sl1.get_custom_value(defs[:shpln_po]).value).to eq('PO1')
      expect(sl1.get_custom_value(defs[:shpln_sku]).value).to eq('SKU1')
      expect(sl1.get_custom_value(defs[:shpln_color]).value).to eq('COL1')
      expect(sl1.get_custom_value(defs[:shpln_size]).value).to eq('SIZE1')
      expect(sl1.get_custom_value(defs[:shpln_coo]).value).to eq('CN')
      expect(sl1.get_custom_value(defs[:shpln_received_date]).value.to_date).to eq(Time.now.to_date) 
      
      sl2 = s.shipment_lines.find_by(line_number: 2)
      expect(sl2.quantity).to eq(11)
      expect(sl2.product).to eq(style1)
      expect(sl2.get_custom_value(defs[:shpln_po]).value).to eq('PO1')
      expect(sl2.get_custom_value(defs[:shpln_sku]).value).to eq('SKU2')
      expect(sl2.get_custom_value(defs[:shpln_color]).value).to eq('COL2')
      expect(sl2.get_custom_value(defs[:shpln_size]).value).to eq('SIZE2')
      expect(sl2.get_custom_value(defs[:shpln_coo]).value).to eq('CN')
      expect(sl2.get_custom_value(defs[:shpln_received_date]).value.to_date).to eq(Time.now.to_date) 
    end
    it "should merge like rows in same shipment" do
      rows = [
        ['1','PO1','SKU1','STY1','COL1','SIZE1','DESC1','CN',10,Time.now.to_date],
        ['1','PO1','SKU1','STY1','COL1','SIZE1','DESC1','CN',10,Time.now.to_date]
      ]
      #this one should be ok
      described_class.new.parse_shipment rows
      expect(ShipmentLine.first.quantity).to eq(20)
    end
  end

end
