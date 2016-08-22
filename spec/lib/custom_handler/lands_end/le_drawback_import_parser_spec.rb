require 'spec_helper'

describe OpenChain::CustomHandler::LandsEnd::LeDrawbackImportParser do
  before :each do
    @le_company = Factory(:company)
    @p = described_class.new @le_company
    @data = "\"IMPORT / CM ENTRY / NO.\",\"PORT CODE\",\"IMPORT DATE\",\"DATE REC'D\",HTS,DESCRIPTION OF MERCHANDISE,Quantity,Column16,UNIT VALUE,Duty Rate
23105002004,3901,10/10/2009,N,10/11/2009,6106100030,2740747 - SHIRT,1,EA,$5,19.70%
23105002004,3901,10/10/2009,N,10/11/2009,6110202079,2769247 - PULLOVER,1,EA,$5.01,16.50%
23105002004,3901,10/10/2009,N,10/11/2009,6110202079,2769247 - PULLOVER,1,EA,$5.01,16.50%
23105002005,3901,10/10/2009,N,10/11/2009,6110202079,2769247 - PULLOVER,1,EA,5.01,16.50%"
  end
  it "should create line" do
    @p.parse @data
    expect(DrawbackImportLine.count).to eq(3)
    d1 = DrawbackImportLine.where(importer_id:@le_company.id,entry_number:'23105002004',part_number:'2740747').first
    expect(d1.description).to eq('SHIRT')
    expect(d1.port_code).to eq('3901')
    expect(d1.import_date).to eq(Date.new(2009,10,10))
    expect(d1.received_date).to eq(Date.new(2009,10,11))
    expect(d1.hts_code).to eq('6106100030')
    expect(d1.part_number).to eq('2740747')
    expect(d1.product.unique_identifier).to eq("LANDSEND-2740747")
    expect(d1.quantity).to eq(1)
    expect(d1.unit_of_measure).to eq('EA')
    expect(d1.unit_price).to eq(5)
    expect(d1.rate).to eq(BigDecimal("0.197"))
  end
  it "should skip subtotal lines" do
    @data.gsub!(/23105002005/,'Subtotal')
    @p.parse @data
    expect(DrawbackImportLine.count).to eq(2)
  end
  it "should skip line where last element is empty" do
    @data.gsub!(/16\.50%/,'')
    @p.parse @data
    expect(DrawbackImportLine.count).to eq(1)
  end

  it "should not call LinkableAttachmentImportRule" do
    expect(LinkableAttachmentImportRule).not_to receive(:exists_for_class?).with(Product)
    @p.parse @data
  end
  it "should update line with incremented quantity" do
    @p.parse @data
    r = DrawbackImportLine.where(importer_id:@le_company.id,part_number:'2769247',entry_number:'23105002004')
    expect(r.count).to eq(1)
    expect(r.first.quantity).to eq(2)
  end
  it "should not update line already put in a download file" do
    @p.parse @data
    d = Factory(:duty_calc_import_file)
    DrawbackImportLine.all.each {|dil| d.duty_calc_import_file_lines.create!(drawback_import_line_id:dil.id)}
    @p.parse @data
    r = DrawbackImportLine.where(importer_id:@le_company.id,part_number:'2769247',entry_number:'23105002004')
    expect(r.count).to eq(2)
    expect(r.first.quantity).to eq(2)
    expect(r.last.quantity).to eq(2)
  end
  it "should not update line for different company" do
    p = Factory(:product,unique_identifier:'LANDSEND-2740747')
    d = DrawbackImportLine.create(importer_id:Factory(:company).id,product_id:p.id,part_number:'2740747',entry_number:'23105002004',quantity:10)
    @p.parse @data
    expect(DrawbackImportLine.count).to eq(4)
    d.reload
    expect(d.quantity).to eq(10)
  end
  it "should import duty per unit from KeyJsonItem" do
    KeyJsonItem.lands_end_cd('23105002004-2740747').first_or_create!(json_data:{entry_number:'23105002004',part_number:'2740747',duty_per_unit:1.2}.to_json)
    @p.parse @data
    expect(DrawbackImportLine.find_by_part_number('2740747').duty_per_unit).to eq(1.2)
  end
end
