require 'spec_helper'

describe OpenChain::CustomHandler::LandsEnd::LeDrawbackImportParser do
  before :each do
    @le_company = Factory(:company)
    @p = described_class.new @le_company
    @data = "\"IMPORT / CM ENTRY / NO.\",\"PORT CODE\",\"IMPORT DATE\",\"DATE REC'D\",HTS,DESCRIPTION OF MERCHANDISE,Quantity,Column16,UNIT VALUE,Duty Rate
23105002004,3901,10/10/2009,10/11/2009,6106100030,2740747 - SHIRT,1,EA,$5,19.70%
23105002004,3901,10/10/2009,10/11/2009,6110202079,2769247 - PULLOVER,1,EA,$5.01,16.50%
23105002004,3901,10/10/2009,10/11/2009,6110202079,2769247 - PULLOVER,1,EA,$5.01,16.50%
23105002005,3901,10/10/2009,10/11/2009,6110202079,2769247 - PULLOVER,1,EA,5.01,16.50%"
  end
  it "should create line" do
    @p.parse @data
    DrawbackImportLine.count.should == 3
    d1 = DrawbackImportLine.where(importer_id:@le_company.id,entry_number:'23105002004',part_number:'2740747').first
    d1.description.should == 'SHIRT'
    d1.port_code.should == '3901'
    d1.import_date.should == Date.new(2009,10,10)
    d1.received_date.should == Date.new(2009,10,11)
    d1.hts_code.should == '6106100030'
    d1.part_number.should == '2740747'
    d1.product.unique_identifier.should == "LANDSEND-2740747"
    d1.quantity.should == 1
    d1.unit_of_measure.should == 'EA'
    d1.unit_price.should == 5
    d1.rate.should == BigDecimal("0.197")
  end
  it "should update line with incremented quantity" do
    @p.parse @data
    r = DrawbackImportLine.where(importer_id:@le_company.id,part_number:'2769247',entry_number:'23105002004')
    r.count.should == 1
    r.first.quantity.should == 2
  end
  it "should not update line already put in a download file" do
    @p.parse @data
    d = Factory(:duty_calc_import_file)
    DrawbackImportLine.all.each {|dil| d.duty_calc_import_file_lines.create!(drawback_import_line_id:dil.id)}
    @p.parse @data
    r = DrawbackImportLine.where(importer_id:@le_company.id,part_number:'2769247',entry_number:'23105002004')
    r.count.should == 2
    r.first.quantity.should == 2
    r.last.quantity.should == 2
  end
  it "should not update line for different company" do
    p = Factory(:product,unique_identifier:'LANDSEND-2740747')
    d = DrawbackImportLine.create(importer_id:Factory(:company).id,product_id:p.id,part_number:'2740747',entry_number:'23105002004',quantity:10)
    @p.parse @data
    DrawbackImportLine.count.should == 4
    d.reload
    d.quantity.should == 10
  end
  it "should import duty per unit from KeyJsonItem" do
    KeyJsonItem.lands_end_cd('23105002004-2740747').first_or_create!(json_data:{entry_number:'23105002004',part_number:'2740747',duty_per_unit:1.2}.to_json)
    @p.parse @data
    DrawbackImportLine.find_by_part_number('2740747').duty_per_unit.should == 1.2
  end
end
