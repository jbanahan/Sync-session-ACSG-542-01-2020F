require 'spec_helper'

describe OpenChain::CustomHandler::JCrewShipmentParser do
  describe :parse_merged_entry_date do
    before :each do
      @importer = Factory(:company,:importer=>true,:alliance_customer_number=>"JCREW")
      @importer_0000 = Factory(:company,:importer=>true,:alliance_customer_number=>"J0000")
      @headings = ["Broker Reference","Customer Number","Entry Number","Arrival Date","Invoice Line - Part Number","Invoice Line - PO Number","Invoice Line - Country Origin Code","PoNo","StyleNo","ColorCode","Size","Dimensions","TotPcs"]
      @data = @headings.to_csv
    end
    it "should create one shipment per entry" do
      row_vals = ["434431","JCREW","31604344312","10/31/2009","20807","1574449","ID","1574449","20807","WP0206","XS","","33"]
      @data << row_vals.to_csv
      row_vals = ["434431","JCREW","31604344312","10/31/2009","20807","1574449","ID","1574449","20807","WP0206","S","","76"]
      @data << row_vals.to_csv
      OpenChain::CustomHandler::JCrewShipmentParser.parse_merged_entry_data @data
      Shipment.all.should have(1).shipment
      s = Shipment.all.first
      s.reference.should == "31604344312"
      s.importer_id = @importer.id
      s.get_custom_value_by_label('Delivery Date').value.should == Date.new(2009,10,31)
      s.should have(2).shipment_lines
      line = s.shipment_lines.first
      line.product.should == Product.find_by_unique_identifier("20807")
      line.quantity.should == 33
      line.get_custom_value_by_label('PO Number').value.should == '1574449'
      line.get_custom_value_by_label('Size').value.should == 'XS'
      line.get_custom_value_by_label('Color').value.should == 'WP0206'
      line = s.shipment_lines.last
      line.product.should == Product.find_by_unique_identifier("20807")
      line.quantity.should == 76 
      line.get_custom_value_by_label('PO Number').value.should == '1574449'
      line.get_custom_value_by_label('Size').value.should == 'S'
      line.get_custom_value_by_label('Color').value.should == 'WP0206'
    end
    it "should parse multiple shipments" do
      row_vals = ["434431","JCREW","31604344312","10/31/2009","20807","1574449","ID","1574449","20807","WP0206","XS","","33"]
      @data << row_vals.to_csv
      row_vals = ["434442","J0000","31604344429","10/31/2009","17932","1578066","CN","1578066","17932","GY6388","P0","","99"]
      @data << row_vals.to_csv
      OpenChain::CustomHandler::JCrewShipmentParser.parse_merged_entry_data @data
      Shipment.all.should have(2).shipments
      s = Shipment.find_by_reference "31604344312"
      s.importer.should == @importer
      s.should have(1).shipment_lines
      sl = s.shipment_lines.first
      sl.product.should == Product.find_by_unique_identifier('20807')
      sl.quantity.should == 33
      s = Shipment.find_by_reference "31604344429"
      s.importer.should == @importer_0000
      s.should have(1).shipment_lines
      sl = s.shipment_lines.first
      sl.product.should == Product.find_by_unique_identifier('17932')
      sl.quantity.should == 99
    end
    it "should combine dimensions for size" do
      row_vals = ["434431","JCREW","31604344312","10/31/2009","20807","1574449","ID","1574449","20807","WP0206","32","34","33"]
      @data << row_vals.to_csv
      OpenChain::CustomHandler::JCrewShipmentParser.parse_merged_entry_data @data
      Shipment.first.shipment_lines.first.get_custom_value_by_label('Size').value.should == '32/34'
    end
  end

end
