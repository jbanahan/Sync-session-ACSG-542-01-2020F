require 'spec_helper'

describe PowerOfAttorney do
  before(:each) do
    @comp = Factory(:company)
    @user = Factory(:user, :company_id => @comp.id)
    @attr = {:company_id => @comp.id,
      :uploaded_by => @user.id,
      :start_date => '2011-12-01',
      :expiration_date => '2011-12-31',
      :attachment_file_name => 'Somedocument.odt'}
  end

  it "should create PowerOfAttorney given valid attributes" do
    PowerOfAttorney.create!(@attr)
  end

  it "should require attachment" do
    PowerOfAttorney.new(@attr.merge(:attachment_file_name => '')).should_not be_valid
  end

  it "shold require user that created it" do
    PowerOfAttorney.new(@attr.merge(:uploaded_by => '')).should_not be_valid
  end

  it "should require company" do
    PowerOfAttorney.new(@attr.merge(:company_id => '')).should_not be_valid
  end

  it "should require start date" do
    PowerOfAttorney.new(@attr.merge(:start_date => '')).should_not be_valid
  end

  it "should require expiration date" do
    PowerOfAttorney.new(@attr.merge(:expiration_date => '')).should_not be_valid
  end
end
