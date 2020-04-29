describe OpenChain::CustomHandler::LandsEnd::LeDrawbackCdParser do
  before :each do
    @le_company = Factory(:company)
    @p = described_class.new @le_company
    @data = "Use,Entry #,Port Code,Import Date,HTS,Description of Merchandise,Qty,UOM,Value Per Unit2,Rate,100% Duty
I,23189224317,3901,10/3/08,6110121050,1049812 - MN V-NECK CASHMERE S,1.00,EA,48.07,0.16,1.92
I,23171852562,3901,4/30/08,6204533010,1090261 - UNF G SLD ALINE SKIR,2.00,PCS,6.98,0.15,2.00"
  end
  it "should create keys" do
    @p.parse @data
    expect(KeyJsonItem.count).to eq(2)
    expect(KeyJsonItem.lands_end_cd('23189224317-1049812').first.data).to eq({'entry_number'=>'23189224317',
      'part_number'=>'1049812', 'duty_per_unit'=>'1.92'
    })
    expect(KeyJsonItem.lands_end_cd('23171852562-1090261').first.data).to eq({'entry_number'=>'23171852562',
      'part_number'=>'1090261', 'duty_per_unit'=>'1.0'
    })
  end
  it "should skip lines where first element is not a single character" do
    @data << "\nGrandTota,23171852562,3901,4/30/08,6204533010,1090261 - UNF G SLD ALINE SKIR,2.00,PCS,6.98,0.15,2.00"
    expect {@p.parse @data}.to change(KeyJsonItem, :count).from(0).to(2)
  end
  it "should build json that can be updated into DrawbackImportLine" do
    @p.parse @data
    d = DrawbackImportLine.new KeyJsonItem.lands_end_cd('23189224317-1049812').first.data
    expect(d.entry_number).to eq('23189224317')
    expect(d.part_number).to eq('1049812')
    expect(d.duty_per_unit).to eq(1.92)
  end
  it "should update existing DrawbackImportLine for same entry / part" do
    p = Factory(:product)
    d = DrawbackImportLine.create!(product_id:p.id, entry_number:'23189224317', part_number:'1049812', :unit_of_measure=>'X', importer_id:@le_company.id)
    @p.parse @data
    d.reload
    expect(d.duty_per_unit).to eq(1.92)
  end
  it "should not update existing DrawbackImportLine for different importer" do
    other_company = Factory(:company)
    p = Factory(:product)
    d = DrawbackImportLine.create!(importer_id:other_company.id, product_id:p.id, entry_number:'23189224317', part_number:'1049812', :unit_of_measure=>'X')
    @p.parse @data
    d.reload
    expect(d.hts_code).to be_nil
  end
end
