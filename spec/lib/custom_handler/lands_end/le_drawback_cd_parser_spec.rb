require 'spec_helper'

describe OpenChain::CustomHandler::LandsEnd::LeDrawbackCdParser do
  before :each do
    @le_company = Factory(:company)
    @p = described_class.new @le_company
    @data = "Use,Entry #,Port Code,Import Date,HTS,Description of Merchandise,Qty,UOM,Value Per Unit2,100% Duty
D,23189224317,3901,10/3/08,6110121050,1049812 - MN V-NECK CASHMERE S,1.00,EA,48.07,1.92
D,23171852562,3901,4/30/08,6204533010,1090261 - UNF G SLD ALINE SKIR,2.00,PCS,6.98,2.00"
  end
  it "should create keys" do
    @p.parse @data
    KeyJsonItem.count.should == 2
    KeyJsonItem.lands_end_cd('23189224317-1049812').first.data.should == {'entry_number'=>'23189224317',
      'part_number'=>'1049812','duty_per_unit'=>'1.92'
    }
    KeyJsonItem.lands_end_cd('23171852562-1090261').first.data.should == {'entry_number'=>'23171852562',
      'part_number'=>'1090261','duty_per_unit'=>'1.0'
    }
  end
  it "should build json that can be updated into DrawbackImportLine" do
    @p.parse @data
    d = DrawbackImportLine.new KeyJsonItem.lands_end_cd('23189224317-1049812').first.data
    d.entry_number.should == '23189224317'
    d.part_number.should == '1049812'
    d.duty_per_unit.should == 1.92
  end
  it "should update existing DrawbackImportLine for same entry / part" do
    p = Factory(:product)
    d = DrawbackImportLine.create!(product_id:p.id,entry_number:'23189224317',part_number:'1049812',:unit_of_measure=>'X',importer_id:@le_company.id)
    @p.parse @data
    d.reload
    d.duty_per_unit.should == 1.92
  end
  it "should not update existing DrawbackImportLine for different importer" do
    other_company = Factory(:company)
    p = Factory(:product)
    d = DrawbackImportLine.create!(importer_id:other_company.id,product_id:p.id,entry_number:'23189224317',part_number:'1049812',:unit_of_measure=>'X')
    @p.parse @data
    d.reload
    d.hts_code.should be_nil
  end
end
