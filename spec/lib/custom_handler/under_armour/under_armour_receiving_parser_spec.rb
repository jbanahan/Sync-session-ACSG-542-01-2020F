require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourReceivingParser do
  before :each do
    @importer = Factory(:company,:importer=>true)
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @xl_client = mock('xl_client')
    @s3_path = 'abc'
    OpenChain::XLClient.should_receive(:new).with(@s3_path).and_return(@xl_client)
    #pass in line number and array of arrays where each sub-array is [column,value, datatype]
    @make_line_lambda = lambda {|line_number,line_array|
      r_val = []
      line_array.each do |ary|
        r_val << {"position"=>{"column"=>ary[0]},"cell"=>{"value"=>ary[1],"datatype"=>ary[2]}}
      end
      @xl_client.should_receive(:get_row).with(0,line_number).and_return(r_val) 
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
  describe :validate do
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
      described_class.validate_s3(@s3_path).should == []
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
      described_class.validate_s3(@s3_path).should == ["Heading at position 3 should be Ship From Country and was Ctry."]
    end
  end
  it "should create custom definitions if they don't exist" do
    custom_defs = {'Country of Origin'=>'string','PO Number'=>'string','Delivery Date'=>'date',
      'Size'=>'string'}
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    CustomDefinition.count.should == 4
    CustomDefinition.all.each do |cd|
      custom_defs.keys.should include cd.label
      cd.module_type.should == (cd.label=="Delivery Date" ? "Shipment" : 'ShipmentLine')
      cd.data_type.should == custom_defs[cd.label]
    end
  end
  it 'should parse single line' do
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    vendors = Company.where(:vendor=>true,:system_code=>'20005')
    vendors.should have(1).item
    vendors.first.name.should == 'COACO (PERU)'
    products = Product.where(:vendor_id=>vendors.first.id,:unique_identifier=>'1100530-413')
    products.should have(1).item
    s = Shipment.find_by_reference '180075781'
    s.should have(1).shipment_lines
    s.vendor.should == vendors.first
    s.importer.should == @importer
    s.get_custom_value(CustomDefinition.find_by_label('Delivery Date')).value.should == Date.new(2010,10,1)
    line = s.shipment_lines.first
    line.line_number.should == 1
    line.product.should == products.first
    line.quantity.should == 4
    line.get_custom_value(CustomDefinition.find_by_label('Country of Origin')).value.should == 'PE'
    line.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '450016177'
    line.get_custom_value(CustomDefinition.find_by_label('Size')).value.should == 'LG'
  end
  it "should strip .0 from size" do
    @line_array[11][1] = "6.0"
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    Shipment.first.shipment_lines.first.get_custom_value(CustomDefinition.find_by_label('Size')).value.should == "6"
  end
  it 'should parse multi-line shipment' do
    @xl_client.should_receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[5][1] = '123456'
    @line_array[9][1] = 'my_style'
    @line_array[15][1] = 10
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    Shipment.count.should == 1
    s = Shipment.first
    s.should have(2).shipment_lines
    line_1 = s.shipment_lines.where(:line_number=>1).first
    line_1.product.should == Product.find_by_unique_identifier('1100530-413')
    line_1.quantity.should == 4
    line_1.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '450016177'
    line_2 = s.shipment_lines.where(:line_number=>2).first
    line_2.product.should == Product.find_by_unique_identifier('my_style')
    line_2.quantity.should == 10
    line_2.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '123456'

  end
  it 'should parse multiple pos for the same ibd / style / size' do
    @xl_client.should_receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[5][1] = "123456"
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    s = Shipment.first
    s.should have(2).shipment_lines
    line_1 = s.shipment_lines.where(:line_number=>1).first
    line_1.get_custom_value(CustomDefinition.find_by_label("PO Number")).value.should == "450016177"
    line_2 = s.shipment_lines.where(:line_number=>2).first
    line_2.get_custom_value(CustomDefinition.find_by_label("PO Number")).value.should == "123456"
  end
  it 'should parse multiple sizes for same ibd / style / po' do
    @xl_client.should_receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[11][1] = "SM"
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    s = Shipment.first
    s.should have(2).shipment_lines
    line_1 = s.shipment_lines.where(:line_number=>1).first
    line_1.get_custom_value(CustomDefinition.find_by_label("Size")).value.should == "LG"
    line_2 = s.shipment_lines.where(:line_number=>2).first
    line_2.get_custom_value(CustomDefinition.find_by_label("Size")).value.should == "SM"
  end
  it 'should parse multiple shipments' do
    @xl_client.should_receive(:last_row_number).with(0).and_return(2)
    @make_line_lambda.call(1,@line_array)
    @line_array[6][1] = 'ibd2'
    @line_array[5][1] = '123456'
    @line_array[9][1] = 'my_style'
    @line_array[15][1] = 10
    @make_line_lambda.call(2,@line_array)
    described_class.parse_s3(@s3_path)
    Shipment.count.should == 2
    s = Shipment.find_by_reference '180075781'
    s.should have(1).shipment_lines
    line_1 = s.shipment_lines.first
    line_1.line_number.should == 1
    line_1.product.should == Product.find_by_unique_identifier('1100530-413')
    line_1.quantity.should == 4
    line_1.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '450016177'
    s = Shipment.find_by_reference 'ibd2'
    s.should have(1).shipment_lines
    line_2 = s.shipment_lines.first
    line_2.line_number.should == 1
    line_2.product.should == Product.find_by_unique_identifier('my_style')
    line_2.quantity.should == 10
    line_2.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '123456'
  end
  it 'should overwrite lines as the style size level' do
    @make_line_lambda.call(1,@line_array)
    @line_array[15][1] = 6 #second line is same style, size, ibd, w different quantity
    @make_line_lambda.call(2,@line_array)
    @xl_client.should_receive(:last_row_number).with(0).and_return(2)
    described_class.parse_s3(@s3_path)
    Shipment.count.should == 1
    s = Shipment.find_by_reference @line_array[6][1]
    s.should have(1).shipment_lines
    s.shipment_lines.first.quantity.should == 6
  end
  it 'should add lines from second in-bound receipt (out of order processing)' do
    original_ibd = @line_array[6][1]
    @make_line_lambda.call(1,@line_array)
    @line_array[6][1] = '180022' #second line is different IBD
    @make_line_lambda.call(2,@line_array)
    @line_array[6][1] = original_ibd #back to the original IBD number w/ different product
    @line_array[9][1] = 'P2'
    @make_line_lambda.call(3,@line_array)
    @xl_client.should_receive(:last_row_number).with(0).and_return(3)
    described_class.parse_s3(@s3_path)
    Shipment.count.should == 2
    s = Shipment.find_by_reference original_ibd
    s.should have(2).shipment_lines
    s.shipment_lines.first.product.unique_identifier.should == '1100530-413'
    s.shipment_lines.first.line_number.should == 1
    s.shipment_lines.last.product.unique_identifier.should == 'P2'
    s.shipment_lines.last.line_number.should == 2
  end
  it 'should clean .0 extensions from numbers that are handled as strings' do
    @line_array[0][1] = '1.0' #vendor id
    @line_array[5][1] = '9999.0' #po
    @line_array[6][1] = '181.0' #ibd
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    described_class.parse_s3(@s3_path)
    s = Shipment.find_by_reference '181'
    s.shipment_lines.first.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '9999'
    s.vendor.system_code.should == '1'
  end
end
