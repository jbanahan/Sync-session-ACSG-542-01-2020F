require 'spec_helper'
require 'open_chain/report'

describe OpenChain::Report::StaleTariffs do

  before(:each) do
    c = Factory(:company, :master=>true)
    @u = Factory(:user, :product_view=>true, :company_id => c.id)
    official_tariff = Factory(:official_tariff)
    @fresh_classification = Factory(:classification, :country_id=>official_tariff.country_id)
    @fresh_tariff_record = Factory(:tariff_record, :hts_1=>official_tariff.hts_code, :classification_id=>@fresh_classification.id)
  end
  
  describe 'security' do
    it 'throws error when user does not have view product & is from master company' do
      @u.should_receive(:view_products?).and_return(false)
      expect {
        OpenChain::Report::StaleTariffs.run_report(@u)
      }.to raise_error(/have permission to view products/)
    end

    it 'throws error when user has view product & is not from master company' do
      c = Factory(:company)
      @u.update_attributes(:company_id=>c.id)
      @u.reload
      expect {
        OpenChain::Report::StaleTariffs.run_report(@u)
      }.to raise_error(/not from company/)
    end
  end

  it 'should generate a tempfile' do
    OpenChain::Report::StaleTariffs.run_report(@u).path.should include '/tmp/'
  end

  context 'with stale tariffs' do
    
    before(:each) do
      @stale_classification = Factory(:classification, :country_id=>@fresh_classification.country_id)
      @stale_tariff_record = Factory(:tariff_record, :classification_id=>@stale_classification.id)
      empty_tariff_record = Factory(:tariff_record, :hts_1=>'', :classification_id=>Factory(:classification).id) #should not be on reports
      classification_with_no_tariffs = Factory(:classification) #should not be on reports
    end

    it 'should show missing tariffs in hts_1' do
      @stale_tariff_record.update_attributes(:hts_1=>'999999')
      wb = Spreadsheet.open OpenChain::Report::StaleTariffs.run_report @u
      sheet = wb.worksheet 0
      sheet.last_row_index.should == 1 #2 total rows
      sheet.row(1)[0].should == @stale_classification.product.unique_identifier
      sheet.row(1)[1].should == @stale_classification.country.name
      sheet.row(1)[2].should == '999999'
    end
    it 'should show missing tariffs in hts_2' do
      @stale_tariff_record.update_attributes(:hts_2=>'9999992')
      wb = Spreadsheet.open OpenChain::Report::StaleTariffs.run_report @u
      sheet = wb.worksheet 0
      sheet.last_row_index.should == 1 #2 total rows
      sheet.row(1)[0].should == @stale_classification.product.unique_identifier
      sheet.row(1)[1].should == @stale_classification.country.name
      sheet.row(1)[2].should == '9999992'
    end
    it 'should show missing tariffs in hts_3' do
      @stale_tariff_record.update_attributes(:hts_3=>'9999993')
      wb = Spreadsheet.open OpenChain::Report::StaleTariffs.run_report @u
      sheet = wb.worksheet 0
      sheet.last_row_index.should == 1 #2 total rows
      sheet.row(1)[0].should == @stale_classification.product.unique_identifier
      sheet.row(1)[1].should == @stale_classification.country.name
      sheet.row(1)[2].should == '9999993'
    end
    it 'should use overriden field names for column headings' do
      FieldLabel.set_label :prod_uid, 'abc'
      @stale_tariff_record.update_attributes(:hts_3=>'9999993')
      wb = Spreadsheet.open OpenChain::Report::StaleTariffs.run_report @u
      sheet = wb.worksheet 0
      sheet.row(0)[0] == 'abc'
    end
  end

  context 'without stale tariffs' do
    it 'should write message in spreadsheet' do
      wb = Spreadsheet.open OpenChain::Report::StaleTariffs.run_report @u
      sheet = wb.worksheet 0
      sheet.row(1)[0].should == "Congratulations! You don't have any stale tariffs."
    end
  end

end
