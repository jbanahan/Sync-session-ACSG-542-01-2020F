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
    expect(PowerOfAttorney.new(@attr.merge(:attachment_file_name => ''))).not_to be_valid
  end

  it "shold require user that created it" do
    expect(PowerOfAttorney.new(@attr.merge(:uploaded_by => ''))).not_to be_valid
  end

  it "should require company" do
    expect(PowerOfAttorney.new(@attr.merge(:company_id => ''))).not_to be_valid
  end

  it "should require start date" do
    expect(PowerOfAttorney.new(@attr.merge(:start_date => ''))).not_to be_valid
  end

  it "should require expiration date" do
    expect(PowerOfAttorney.new(@attr.merge(:expiration_date => ''))).not_to be_valid
  end
end
