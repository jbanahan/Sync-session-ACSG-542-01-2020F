require 'test_helper'

class FieldValidatorRuleTest < ActiveSupport::TestCase

  test 'prepend nested module type' do
    f = FieldValidatorRule.new(:model_field_uid=>"prod_uid",:regex=>"123",:custom_message=>"c")
    expected = "#{CoreModule::PRODUCT.label}: #{f.custom_message}"
    found = f.validate_field Product.new(:unique_identifier=>"x"), true
    assert expected==found
  end

  test 'auto set module_type' do
    #module_type should be auto set on validate based on the model_field_uid
    f = FieldValidatorRule.new(:model_field_uid=>"prod_uid")
    assert f.module_type.nil?
    assert f.valid?
    assert f.module_type==CoreModule::PRODUCT.class_name
  end

  test 'find_cached_by_core_module' do 
    FieldValidatorRule.create!(:model_field_uid=>"prod_uid")
    FieldValidatorRule.create!(:model_field_uid=>"prod_name")
    FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num") #shouldn't find this one
    found = FieldValidatorRule.find_cached_by_core_module CoreModule::PRODUCT
    assert found.size==2
    found_uids = found.collect {|f| f.model_field_uid}
    assert found_uids.include?("prod_uid")
    assert found_uids.include?("prod_name")
  end

  test 'regex with number' do 
    f = FieldValidatorRule.new(:model_field_uid=>"delln_line_number",:regex=>"12")
    d = DeliveryLine.new(:line_number=>12)
    assert f.validate_field(d).nil?
    d.line_number = 13
    assert !f.validate_field(d).nil?
  end
  test 'regex validation' do 
    f = FieldValidatorRule.new(:model_field_uid=>"ord_ord_num")
    f.regex = "^abc"
    expected_message = "#{ModelField.find_by_uid(:ord_ord_num).label} must match expression #{f.regex}."
    o = Order.new(:order_number=>"abc") #case insensitive so this should pass
    assert f.validate_field(o).nil?
    o.order_number= "ABC"
    assert f.validate_field(o).nil?
    o.order_number= "def"
    msg = f.validate_field(o)
    assert msg==expected_message, "Expected #{expected_message}, got #{msg}"
    o.order_number= ""
    assert f.validate_field(o).nil? #not required so should pass
    f.required=true
    assert f.validate_field(o)==expected_message #required, so blank should fail
    f.regex=""
    assert f.validate_field(o).nil? #don't try to validate if regex is blank
    o.order_number = "fail"
  end

  test "Custom Message" do
    p = Product.new(:unique_identifier=>"123")
    f = FieldValidatorRule.new(:regex=>"fail",:model_field_uid=>"prod_uid",:custom_message=>"My message")
    msg = f.validate_field(p)
    assert msg==f.custom_message, "Expected #{f.custom_message}, got #{msg}"
  end
end
