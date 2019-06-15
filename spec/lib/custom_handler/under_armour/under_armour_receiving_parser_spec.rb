describe OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser do
  before :each do
    @importer = Factory(:company, master: true, importer: true)
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @xl_client = double('xl_client')
    @s3_path = 'abc'
    expect(OpenChain::XLClient).to receive(:new).with(@s3_path).and_return(@xl_client)
    #pass in line number and array of arrays where each sub-array is [column,value, datatype]
    @make_line_lambda = lambda {|line_number,line_array|
      r_val = []
      line_array.each do |ary|
        r_val << {"position"=>{"column"=>ary[0]},"cell"=>{"value"=>ary[1],"datatype"=>ary[2]}}
      end
      expect(@xl_client).to receive(:get_row).with(0,line_number).and_return(r_val)
    }
    @line_array = [
      [0,20005,'number'],
      [1,'COACO (PERU)','string'],
      [2,'@F','string'], #stock category (ignored)
      [3,'PE','string'],
      [4,'PERU','string'],
      [5,'450016177','number'], #PO
      [6,'180075781','number'], #IBD (ship ref)
      [7,Date.new(2010,10,01),'datetime'],
      [8,Date.new(2010,10,04),'datetime'],
      [9,'1100530-413','string'],
      [10,'TRADITIONAL STRIP POLO-BLN','string'],
      [11,'LG','string'],
      [12,10,'number'],
      [13,'Distribution House','string'],
      [16,'ZD','string'],
      [17,4,'number'],
      [18,'12.83','number'],
      [19,'51.32','number'],
    ]
  end
  describe "validate" do
    it "should pass with good headings" do
      good = [
        [0,'Vendor','string'],
        [1,'','string'],
        [2,'Stock Category','string'],
        [3,'Ship From Country','string'],
        [4,'','string'],
        [5,'PO Number','string'],
        [6,'IBD Number','string'],
        [7,'Delivery Date','string'],
        [8,'AGI Date','string'],
        [9,'Material','string'],
        [10,'','string'],
        [11,'Grid Value','string'],
        [12,'Plant','string'],
        [13,'','string'],
        [14,'Company Code','string'],
        [15,'','string'],
        [16,'PO Doc Type','string'],
        [17,'Delivery Qty','string'],
        [18,'AFS Net Price','string'],
        [19,'Delivery Value','string']
      ]
      @make_line_lambda.call(0,good)
      expect(described_class.validate_s3(@s3_path)).to eq([])
    end
    it "should fail with bad headings" do
      bad = [
        [0,'Vendor','string'],
        [1,'','string'],
        [2,'Stock Category','string'],
        [3,'Ctry','string'],
        [4,'','string'],
        [5,'PO Number','string'],
        [6,'IBD Number','string'],
        [7,'Delivery Date','string'],
        [8,'AGI Date','string'],
        [9,'Material','string'],
        [10,'','string'],
        [11,'Grid Value','string'],
        [12,'Plant','string'],
        [13,'','string'],
        [14,'Company Code','string'],
        [15,'','string'],
        [16,'PO Doc Type','string'],
        [17,'Delivery Qty','string'],
        [18,'AFS Net Price','string'],
        [19,'Delivery Value','string']
      ]
      @make_line_lambda.call(0,bad)
      expect(described_class.validate_s3(@s3_path)).to eq(["Heading at position 3 should be Ship From Country and was Ctry."])
    end
  end
  it "should create custom definitions if they don't exist" do
    custom_defs = {'Country of Origin'=>'string','PO Number'=>'string','Delivery Date'=>'date',
      'Size'=>'string','Color'=>'string'}
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    expect(CustomDefinition.count).to eq(5)
    CustomDefinition.all.each do |cd|
      expect(custom_defs.keys).to include cd.label
      expect(cd.module_type).to eq(cd.label=="Delivery Date" ? "Shipment" : 'ShipmentLine')
      expect(cd.data_type).to eq(custom_defs[cd.label])
    end
  end
  it 'should parse single line' do
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    vendors = Company.where(:vendor=>true,:system_code=>'20005')
    expect(vendors.size).to eq(1)
    expect(vendors.first.name).to eq('COACO (PERU)')
    products = Product.where(:unique_identifier=>'1100530')
    expect(products.size).to eq(1)
    s = Shipment.find_by(reference: '180075781')
    expect(s.shipment_lines.size).to eq(1)
    expect(s.vendor).to eq(vendors.first)
    expect(s.importer).to eq(@importer)
    expect(s.get_custom_value(CustomDefinition.find_by(label: 'Delivery Date')).value).to eq(Date.new(2010,10,1))
    line = s.shipment_lines.first
    expect(line.line_number).to eq(1)
    expect(line.product).to eq(products.first)
    expect(line.quantity).to eq(4)
    expect(line.get_custom_value(CustomDefinition.find_by(label: 'Country of Origin')).value).to eq('PE')
    expect(line.get_custom_value(CustomDefinition.find_by(label: 'PO Number')).value).to eq('450016177')
    expect(line.get_custom_value(CustomDefinition.find_by(label: 'Size')).value).to eq('LG')
    expect(line.get_custom_value(CustomDefinition.find_by(label: 'Color')).value).to eq('413')
  end
  it "should skip result lines" do
    @line_array[6][1] = 'Result'
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    expect{described_class.parse_s3(@s3_path)}.to_not change(Shipment,:count)
  end
  it "should strip .0 from size" do
    @line_array[11][1] = "6.0"
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    expect(Shipment.first.shipment_lines.first.get_custom_value(CustomDefinition.find_by(label: 'Size')).value).to eq("6")
  end
  it 'should parse multi-line shipment' do
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[5][1] = '123456'
    @line_array[9][1] = '987654-321'
    @line_array[15][1] = 10
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    po_cdef = CustomDefinition.find_by(label: 'PO Number')
    color_cdef = CustomDefinition.find_by(label: 'Color')
    expect(Shipment.count).to eq(1)
    s = Shipment.first
    expect(s.shipment_lines.size).to eq(2)
    line_1 = s.shipment_lines.where(:line_number=>1).first
    expect(line_1.product).to eq(Product.find_by_unique_identifier('1100530'))
    expect(line_1.quantity).to eq(4)
    expect(line_1.get_custom_value(po_cdef).value).to eq('450016177')
    expect(line_1.get_custom_value(color_cdef).value).to eq('413')
    line_2 = s.shipment_lines.where(:line_number=>2).first
    expect(line_2.product).to eq(Product.find_by_unique_identifier('987654'))
    expect(line_2.quantity).to eq(10)
    expect(line_2.get_custom_value(po_cdef).value).to eq('123456')
    expect(line_2.get_custom_value(color_cdef).value).to eq('321')

  end
  it 'should parse multiple pos for the same ibd / style / size' do
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[5][1] = "123456"
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    s = Shipment.first
    expect(s.shipment_lines.size).to eq(2)
    line_1 = s.shipment_lines.where(:line_number=>1).first
    expect(line_1.get_custom_value(CustomDefinition.find_by(label: "PO Number")).value).to eq("450016177")
    line_2 = s.shipment_lines.where(:line_number=>2).first
    expect(line_2.get_custom_value(CustomDefinition.find_by(label: "PO Number")).value).to eq("123456")
  end
  it 'should parse multiple colors for the same ibd / style / po' do
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[9][1] = "1100530-123"
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    color_cdef = CustomDefinition.find_by(label: 'Color')
    s = Shipment.first
    expect(s.shipment_lines.size).to eq(2)
    line_1 = s.shipment_lines.where(:line_number=>1).first
    expect(line_1.get_custom_value(color_cdef).value).to eq("413")
    line_2 = s.shipment_lines.where(:line_number=>2).first
    expect(line_2.get_custom_value(color_cdef).value).to eq("123")
  end
  it 'should parse multiple sizes for same ibd / style / po' do
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[11][1] = "SM"
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    s = Shipment.first
    expect(s.shipment_lines.size).to eq(2)
    line_1 = s.shipment_lines.where(:line_number=>1).first
    expect(line_1.get_custom_value(CustomDefinition.find_by(label: "Size")).value).to eq("LG")
    line_2 = s.shipment_lines.where(:line_number=>2).first
    expect(line_2.get_custom_value(CustomDefinition.find_by(label: "Size")).value).to eq("SM")
  end
  it 'should parse multiple shipments' do
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[6][1] = 'ibd2'
    @line_array[5][1] = '123456'
    @line_array[9][1] = '123-456'
    @line_array[15][1] = 10
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    expect(Shipment.count).to eq(2)
    s = Shipment.find_by_reference '180075781'
    expect(s.shipment_lines.size).to eq(1)
    line_1 = s.shipment_lines.first
    expect(line_1.line_number).to eq(1)
    expect(line_1.product).to eq(Product.find_by_unique_identifier('1100530'))
    expect(line_1.quantity).to eq(4)
    expect(line_1.get_custom_value(CustomDefinition.find_by(label: 'PO Number')).value).to eq('450016177')
    s = Shipment.find_by_reference 'ibd2'
    expect(s.shipment_lines.size).to eq(1)
    line_2 = s.shipment_lines.first
    expect(line_2.line_number).to eq(1)
    expect(line_2.product).to eq(Product.find_by_unique_identifier('123'))
    expect(line_2.quantity).to eq(10)
    expect(line_2.get_custom_value(CustomDefinition.find_by(label: 'PO Number')).value).to eq('123456')
  end
  it 'should overwrite lines as the style color size level' do
    @make_line_lambda.call(1,@line_array)
    @line_array[15][1] = 6 #second line is same style, color, size, ibd, w different quantity
    @make_line_lambda.call(2,@line_array)
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(2)
    described_class.parse_s3(@s3_path)
    expect(Shipment.count).to eq(1)
    s = Shipment.find_by_reference @line_array[6][1]
    expect(s.shipment_lines.size).to eq(1)
    expect(s.shipment_lines.first.quantity).to eq(6)
  end
  it 'should add lines from second in-bound receipt (out of order processing)' do
    original_ibd = @line_array[6][1]
    @make_line_lambda.call(1,@line_array)
    @line_array[6][1] = '180022' #second line is different IBD
    @make_line_lambda.call(2,@line_array)
    @line_array[6][1] = original_ibd #back to the original IBD number w/ different product
    @line_array[9][1] = '123-456'
    @make_line_lambda.call(3,@line_array)
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(3)
    described_class.parse_s3(@s3_path)
    expect(Shipment.count).to eq(2)
    s = Shipment.find_by_reference original_ibd
    expect(s.shipment_lines.size).to eq(2)
    expect(s.shipment_lines.first.product.unique_identifier).to eq('1100530')
    expect(s.shipment_lines.first.line_number).to eq(1)
    expect(s.shipment_lines.last.product.unique_identifier).to eq('123')
    expect(s.shipment_lines.last.line_number).to eq(2)
  end
  it 'should clean .0 extensions from numbers that are handled as strings' do
    @line_array[0][1] = '1.0' #vendor id
    @line_array[5][1] = '9999.0' #po
    @line_array[6][1] = '181.0' #ibd
    expect(@xl_client).to receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    s = Shipment.find_by_reference '181'
    expect(s.shipment_lines.first.get_custom_value(CustomDefinition.find_by(label: 'PO Number')).value).to eq('9999')
    expect(s.vendor.system_code).to eq('1')
  end
end
