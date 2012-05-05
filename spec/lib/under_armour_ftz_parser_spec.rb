require 'spec_helper'

describe OpenChain::UnderArmourFtzParser do

  before :each do
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
      [0,1565,"number"], #EZFTZ Entry Number
      [1,"113-4873417-6","string"], #real entry number
      [2,85194074,"number"], #outbound ref number
      [3,"1100616-600","string"], #product code
      [4,"8.0","number"], #size code
      [5,1,"number"], #quantity
      [6,"PH","string"], #country of origin
      [7,6101302010,"number"], #hts code
      [8,12.1,"number"], #entered value
      [9,3.4122,"number"], #total duty
      [10,0.282,"number"], #advalorem duty rate
      [11,0,"number"], #specific duty rate
      [12,0,"number"], #supplemental duty rate
      [13,"OUTER LIMITS","string"] #description
    ]
    @entered_date = 1.day.ago
    @box_37_value = 10000
    @box_40_value = 10485
    @port_code = "1303"
    @total_entered_value = 1000000
    @total_mpf = 485
  end
  it "should create an entry" do
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    OpenChain::UnderArmourFtzParser.parse_s3(@s3_path,@entered_date,@box_37_value,@box_40_value,@port_code,@total_entered_value,@total_mpf)
    ent = Entry.find_by_entry_number "11348734176"
    ent.entry_port_code.should == @port_code
    ent.arrival_date.strftime("%Y%m%d").should == 1.day.ago.strftime("%Y%m%d")
    ent.total_invoiced_value.should == @total_entered_value
    ent.total_duty.should == @box_37_value
    ent.total_duty_direct.should == @box_40_value
    ent.merchandise_description.should == "WEARING APPAREL, FOOTWEAR"
    ent.mpf.should == @total_mpf
    ent.should have(1).commercial_invoices
    inv = ent.commercial_invoices.first
    inv.invoice_number.should == "N/A"
    lines = inv.commercial_invoice_lines
    lines.should have(1).item
    line = lines.first
    line.part_number.should == "1100616-600"
    line.po_number.should == "85194074"
    line.quantity.should == 1
    line.should have(1).commercial_invoice_tariffs
    t = line.commercial_invoice_tariffs.first
    t.duty_amount.should == 3.41
    t.classification_qty_1.should == 1
    t.classification_uom_1.should == "EA"
    t.hts_code.should == "6101302010"
    t.entered_value.should == 12.1
  end
  it "should set entry to existing importer" do
    c = Factory(:company,:importer=>true,:name=>OpenChain::UnderArmourFtzParser::IMPORTER_NAME)
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    OpenChain::UnderArmourFtzParser.parse_s3(@s3_path,@entered_date,@box_37_value,@box_40_value,@port_code,@total_entered_value,@total_mpf)
    ent = Entry.find_by_entry_number "11348734176"
    ent.importer.should == c
  end
  it "should create importer if it doesn't already exist" do
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    OpenChain::UnderArmourFtzParser.parse_s3(@s3_path,@entered_date,@box_37_value,@box_40_value,@port_code,@total_entered_value,@total_mpf)
    ent = Entry.find_by_entry_number "11348734176"
    ent.importer.should be_importer
    ent.importer.name.should == OpenChain::UnderArmourFtzParser::IMPORTER_NAME
  end
  it "should create a shipment" do
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    OpenChain::UnderArmourFtzParser.parse_s3(@s3_path,@entered_date,@box_37_value,@box_40_value,@port_code,@total_entered_value,@total_mpf)
    s = Shipment.find_by_reference("113-4873417-6")
    s.vendor.name.should == OpenChain::UnderArmourFtzParser::GENERIC_UA_VENDOR_NAME
    s.get_custom_value(CustomDefinition.find_by_label('Delivery Date')).value.strftime("%Y%m%d").should == @entered_date.strftime("%Y%m%d")
    s.should have(1).shipment_lines
    line = s.shipment_lines.first
    line.line_number.should == 1
    line.product.should == Product.find_by_unique_identifier("1100616-600")
    line.quantity.should == 1
    line.get_custom_value(CustomDefinition.find_by_label('Country of Origin')).value.should == 'PH'
    line.get_custom_value(CustomDefinition.find_by_label('PO Number')).value.should == '85194074'
    line.get_custom_value(CustomDefinition.find_by_label('Size')).value.should == '8'
  end
  context :multiple_lines do
    before :each do
      @xl_client.should_receive(:last_row_number).with(0).and_return(2)
      @make_line_lambda.call(1,@line_array)
      @line_array[2][1] = "464654640"
      @line_array[3][1] = "4445556-550"
      @line_array[4][1] = "MD"
      @make_line_lambda.call(2,@line_array)
      OpenChain::UnderArmourFtzParser.parse_s3(@s3_path,@entered_date,@box_37_value,@box_40_value,@port_code,@total_entered_value,@total_mpf)
    end
    it "should process multiple lines into one entry" do
      Entry.find_by_entry_number("11348734176").
        commercial_invoices.first.
        should have(2).commercial_invoice_lines
    end
    it "should process multiple lines into one shipment" do
      Shipment.first.should have(2).shipment_lines
    end
  end

  it "should create custom definitions if they don't exist" do
    custom_defs = {'Country of Origin'=>'string','PO Number'=>'string','Delivery Date'=>'date',
      'Size'=>'string'}
    @xl_client.should_receive(:last_row_number).with(0).and_return(1)
    @make_line_lambda.call(1,@line_array)
    OpenChain::UnderArmourFtzParser.parse_s3(@s3_path,@entered_date,@box_37_value,@box_40_value,@port_code,@total_entered_value,@total_mpf)
    CustomDefinition.count.should == 4
    CustomDefinition.all.each do |cd|
      custom_defs.keys.should include cd.label
      cd.module_type.should == (cd.label=="Delivery Date" ? "Shipment" : 'ShipmentLine')
      cd.data_type.should == custom_defs[cd.label]
    end
  end
end
