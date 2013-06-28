require 'test_helper'
require 'open_chain/field_logic'

class FieldLogicValidatorTest < ActiveSupport::TestCase

  test "one of array - empty" do 
    f = FieldValidatorRule.new
    result = f.one_of_array
    assert result.size==0
    f.one_of = "    "
    result = f.one_of_array
    assert result.size==0
  end

  test "one of array" do
    f = FieldValidatorRule.new(:one_of=>"abc \ndef, \nghi\n 1991$(10)")
    result = f.one_of_array
    assert result.size==4, "Expected 4, got #{result.size}"
    expected = ["abc","def,","ghi","1991$(10)"]
    assert result==expected
  end

  test "base failure" do
    f = FieldValidatorRule.create!(:model_field_uid=>"prod_uid",:regex=>"abc",:custom_message=>"failed!")
    p = Product.new(:unique_identifier=>"def")
    assert !OpenChain::FieldLogicValidator.validate(p)
    assert p.errors[:base].size==1
    msg = p.errors[:base].first
    assert msg==f.custom_message, "Expected #{f.custom_message}, got #{msg}"
    p.unique_identifier="abc"
    p.errors[:base].clear
    assert OpenChain::FieldLogicValidator.validate(p)
    assert p.errors[:base].size==0
  end

  test "nested failure" do
    f = FieldValidatorRule.create!(:model_field_uid=>"hts_line_number",:regex=>"z",:custom_message=>"failed regex")
    p = Product.new()
    c = p.classifications.build
    t = c.tariff_records.build(:line_number=>1)
    assert !OpenChain::FieldLogicValidator.validate(p)
    assert p.errors.size==1
    msg = p.errors[:base].first
    assert msg=="#{CoreModule::TARIFF.label}: #{f.custom_message}"
  end

end
