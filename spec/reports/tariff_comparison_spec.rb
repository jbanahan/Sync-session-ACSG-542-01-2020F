require 'spec_helper'
require 'open_chain/report'
require 'spreadsheet'

describe OpenChain::Report::TariffComparison do
  before(:each) do
    @country = Factory(:country)
    @old_ts = TariffSet.create!(:country_id=>@country.id,:label=>'a')
    @new_ts = TariffSet.create!(:country_id=>@country.id,:label=>'b')
    @unchanged_hts = '123456789'
    @changed_hts = '5556667778'
    @changed_2 = '159753456'
    [@old_ts,@new_ts].each_with_index do |t, i|
      t.tariff_set_records.create!(:country_id=>@country.id,:hts_code=>@unchanged_hts,:full_description=>'not changed',:general_rate=>'.123/kg')
      t.tariff_set_records.create!(:country_id=>@country.id,:hts_code=>@changed_hts,:full_description=>'desc',:general_rate=>t.label, :unit_of_measure=>i)
      t.tariff_set_records.create!(:country_id=>@country.id,:hts_code=>@changed_2,:full_description=>'desc',:unit_of_measure=>i)
    end
    @removed = @old_ts.tariff_set_records.create!(:country_id=>@country.id,:hts_code=>'654987321')
    @added = @new_ts.tariff_set_records.create!(:country_id=>@country.id,:hts_code=>'987654321')
    @user = Factory(:user)
  end

  context 'good process' do
    before(:each) do 
      @t = OpenChain::Report::TariffComparison.run_report @user, {'old_tariff_set_id'=>@old_ts.id,'new_tariff_set_id'=>@new_ts.id}
      @wb = Spreadsheet.open @t.path
    end

    it "should output to a tempfile" do
      @t.path.should include '/tmp/'
    end
    
    it "should show added tariffs on first tab" do
      sheet = @wb.worksheet 0
      sheet.last_row_index.should == 1 #2 total rows
      sheet.row(1)[0].should == @added.hts_code
    end
    it "should show removed tariffs on second tab" do
      sheet = @wb.worksheet 1
      sheet.last_row_index.should == 1 #2 total rows
      sheet.row(1)[0].should == @removed.hts_code
    end
    it "should show changed tariffs on third tab" do
      sheet = @wb.worksheet 2
      sheet.row(0)[1].should == @changed_hts
      sheet.row(1).should == [nil, "Attribute", "New Value", "Old Value"]
      sheet.row(2).should == [nil, "general_rate", "b", "a"]
      sheet.row(3).should == [nil, "unit_of_measure", "1", "0"]
      sheet.row(4).should == [nil]

      sheet.row(5)[1].should == @changed_2
      sheet.row(6).should == [nil, "Attribute", "New Value", "Old Value"]
      sheet.row(7).should == [nil, "unit_of_measure", "1", "0"]
      sheet.row(8).should == [nil]
    end
  end

  context "error conditions" do
    it "should fail if both tariff sets are not included in settings hash" do
      expect {
        OpenChain::Report::TariffComparison.run_report(@user, {})
      }.to raise_error "Two tariff sets are required."
    end
    it "should fail if both tariff sets are not from the same country" do
      @old_ts.update_attributes(:country_id=>Country.create(:iso_code=>'OT',:name=>"other").id)
      expect {
        OpenChain::Report::TariffComparison.run_report(@user, {'old_tariff_set_id'=>@old_ts.id,'new_tariff_set_id'=>@new_ts.id})
      }.to raise_error "Both tariff sets must be from the same country."
    end
  end
end
