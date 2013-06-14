require 'spec_helper'

describe Country do
  it "should reload model field on save" do
    ModelField.should_receive(:reload).with(true)
    Country.create!(:name=>'MYC',:iso_code=>'YC')
  end
end
