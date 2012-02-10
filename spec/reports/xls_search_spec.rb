require 'spec_helper'

describe OpenChain::Report::XLSSearch do
  before :each do
    @user = Factory(:user,:company_id=>Factory(:company,:master=>true).id,:product_view=>true) 
    @product = Factory(:product,:name=>'abc123')
    @search = Factory(:search_setup,:user=>@user,:module_type=>'Product')
    @search.search_columns.create(:model_field_uid=>'prod_name',:rank=>0)
    @search.search_criterions.create!(:model_field_uid=>'prod_name',:operator=>'eq',:value=>@product.name)
  end

  it 'should run a simple search' do
    wb = Spreadsheet.open OpenChain::Report::XLSSearch.run_report @user, 'search_setup_id'=>@search.id
    sheet = wb.worksheet 0
    sheet.last_row_index.should == 1 #2 total rows
    sheet.row(0)[0].should == ModelField.find_by_uid('prod_name').label
    sheet.row(1)[0].should == @product.name
  end

  it 'should fail if run_by is different than search setup user' do
    u2 = Factory(:user)
    expect {
      OpenChain::Report::XLSSearch.run_report u2, 'search_setup_id'=>@search.id
    }.to raise_error
  end
end
