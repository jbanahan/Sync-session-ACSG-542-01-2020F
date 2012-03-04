require 'test_helper'

class FieldValidatorRuleTest < ActiveSupport::TestCase


  test "minimum length" do
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:minimum_length=>3,:custom_message=>"1010")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input "abc"
    assert found.empty?
    found = f.validate_input "abcd"
    assert found.empty?
    found = f.validate_input "a"
    assert found.first==f.custom_message
    found = f.validate_input "ab  " #should fail because whitespace doesn't count
    assert found.first==f.custom_message
    found = f.validate_input ""
    assert found.empty?
    found = f.validate_input nil
    assert found.empty?
  end

  test 'one of' do
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:one_of=>"abc\n123\ndef\n2011-01-01")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    expected_message = "#{ModelField.find_by_uid(:ord_ord_num).label} must be one of: abc, 123, def, 2011-01-01." 
    found = f.validate_input "abc"
    assert found.empty?
    found = f.validate_input "123"
    assert found.empty?
    found = f.validate_input "deF" #case insensitive, so should pass
    assert found.empty?
    found = f.validate_input "abc123"
    assert found.first==expected_message, "Expected #{expected_message}, found: #{found.first}"
    found = f.validate_input 123
    assert found.empty? #numbers should pass
    found = f.validate_input Date.new(2011,1,1)
    assert found.empty? #dates should pass
    found = f.validate_input 123.1
    assert found.first==expected_message
    found = f.validate_input Date.new(2010,1,1)
    assert found.first==expected_message
  end

  test 'contains' do
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:custom_message=>"123",:contains=>"zz")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input "aazz"
    assert found.empty?
    found = f.validate_input "aaZz" #case insensitive, so should pass
    assert found.empty?
    found = f.validate_input "azza"
    assert found.empty?
    found = f.validate_input "zaaz"
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
    found = f.validate_input ""
    assert found.empty?
  end

  test 'ends with' do 
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:custom_message=>"zz",:ends_with=>"zz")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input "aazz"
    assert found.empty?
    found = f.validate_input "aaZz" #case insensitive, so should pass
    assert found.empty?
    found = f.validate_input "azza"
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
    found = f.validate_input ""
    assert found.empty?
  end

  test 'starts with' do
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:custom_message=>"qq",:starts_with=>"zz")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input "zzaa"
    assert found.empty?
    found = f.validate_input "Zzaa" #case insensitive, so should pass
    assert found.empty?
    found = f.validate_input "azza"
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
    found = f.validate_input ""
    assert found.empty?
  end

  test 'validate less than from now' do
    #days weeks months years
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_date",:custom_message=>"bb",:less_than_from_now=>3,:less_than_from_now_uom=>"days")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input 2.days.from_now 
    assert found.empty?
    found = f.validate_input Time.now
    assert found.empty?
    found = f.validate_input 4.days.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.less_than_from_now.days.from_now
    assert found.first==f.custom_message
    found = f.validate_input 2.days.ago
    assert found.empty?

    f.less_than_from_now_uom="weeks"
    found = f.validate_input 2.weeks.from_now 
    assert found.empty?
    found = f.validate_input Time.now
    assert found.empty?
    found = f.validate_input 4.weeks.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.less_than_from_now.weeks.from_now
    assert found.first==f.custom_message
    found = f.validate_input 2.weeks.ago
    assert found.empty?

    f.less_than_from_now_uom="months"
    found = f.validate_input 2.months.from_now 
    assert found.empty?
    found = f.validate_input Time.now
    assert found.empty?
    found = f.validate_input 4.months.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.less_than_from_now.months.from_now
    assert found.first==f.custom_message
    found = f.validate_input 2.months.ago
    assert found.empty?

    f.less_than_from_now_uom="years"
    found = f.validate_input 2.years.from_now 
    assert found.empty?
    found = f.validate_input Time.now
    assert found.empty?
    found = f.validate_input 4.years.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.less_than_from_now.years.from_now
    assert found.first==f.custom_message
    found = f.validate_input 2.years.ago
    assert found.empty?
  end

  test 'validate more than ago' do
    #days weeks months years
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_date",:custom_message=>"bb",:more_than_ago=>3,:more_than_ago_uom=>"days")
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input 4.days.ago
    assert found.empty?
    found = f.validate_input Time.now
    assert found.first==f.custom_message
    found = f.validate_input 1.days.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.more_than_ago.days.ago
    assert found.first==f.custom_message
    found = f.validate_input 2.days.ago
    assert found.first==f.custom_message

    f.more_than_ago_uom="weeks"
    found = f.validate_input 4.weeks.ago
    assert found.empty?
    found = f.validate_input Time.now
    assert found.first==f.custom_message
    found = f.validate_input 1.weeks.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.more_than_ago.weeks.ago
    assert found.first==f.custom_message
    found = f.validate_input 2.weeks.ago
    assert found.first==f.custom_message

    f.more_than_ago_uom="months"
    found = f.validate_input 4.months.ago
    assert found.empty?
    found = f.validate_input Time.now
    assert found.first==f.custom_message
    found = f.validate_input 1.months.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.more_than_ago.months.ago
    assert found.first==f.custom_message
    found = f.validate_input 2.months.ago
    assert found.first==f.custom_message

    f.more_than_ago_uom="years"
    found = f.validate_input 4.years.ago
    assert found.empty?
    found = f.validate_input Time.now
    assert found.first==f.custom_message
    found = f.validate_input 1.years.from_now
    assert found.first==f.custom_message
    found = f.validate_input f.more_than_ago.years.ago
    assert found.first==f.custom_message
    found = f.validate_input 2.years.ago
    assert found.first==f.custom_message
  end

  test 'validate greater than date' do
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_date",:custom_message=>"aa",:greater_than_date=>Date.new(2011,1,1))
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input Date.new(2012,1,1)
    assert found.empty?
    found = f.validate_input Date.new(2011,1,1)
    assert found.first==f.custom_message
    found = f.validate_input Date.new(2010,1,1)
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
  end
  
  test 'validate less than date' do
    f = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_date",:custom_message=>"aa",:less_than_date=>Date.new(2011,1,1))
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input Date.new(2010,1,1)
    assert found.empty?
    found = f.validate_input Date.new(2011,1,1)
    assert found.first==f.custom_message
    found = f.validate_input Date.new(2012,1,1)
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
  end

  test 'validate less than' do
    #decimal
    f = FieldValidatorRule.create!(:model_field_uid=>"ordln_ordered_qty",:custom_message=>"xx",:less_than=>10.4)
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input 10.3
    assert found.empty?
    found = f.validate_input 10.4
    assert found.first==f.custom_message, "Expected #{f.custom_message}, got #{found.first}"
    found = f.validate_input 10.5
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
    
    #integer
    f = FieldValidatorRule.create!(:model_field_uid=>"ordln_line_number",:custom_message=>"yy",:less_than=>8)
    f = FieldValidatorRule.find f.id
    found = f.validate_input 7
    assert found.empty?
    found = f.validate_input 8
    assert found.first==f.custom_message
    found = f.validate_input 9
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
  end
  test 'validate greater than' do
    #decimal
    f = FieldValidatorRule.create!(:model_field_uid=>"ordln_ordered_qty",:custom_message=>"xx",:greater_than=>10.4)
    f = FieldValidatorRule.find f.id #make sure we read from the DB to ensure data types are loaded properly
    found = f.validate_input 10.5
    assert found.empty?
    found = f.validate_input 10.4
    assert found.first==f.custom_message, "Expected #{f.custom_message}, got #{found.first}"
    found = f.validate_input 10.3
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
    
    #integer
    f = FieldValidatorRule.create!(:model_field_uid=>"ordln_line_number",:custom_message=>"yy",:greater_than=>8)
    f = FieldValidatorRule.find f.id
    found = f.validate_input 9
    assert found.empty?
    found = f.validate_input 8
    assert found.first==f.custom_message
    found = f.validate_input 7
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.empty?
  end
  test 'validate required' do 
    f = FieldValidatorRule.new(:model_field_uid=>"prod_uid",:required=>true,:custom_message=>"z")
    found = f.validate_input ""
    assert found.first==f.custom_message
    found = f.validate_input nil
    assert found.first==f.custom_message
    found = f.validate_input "a"
    assert found.empty?
    found = f.validate_input 123
    assert found.empty?
    found = f.validate_input Time.now
    assert found.empty?
  end

  test 'validate input' do
    f = FieldValidatorRule.new(:model_field_uid=>"prod_uid",:regex=>"123",:custom_message=>"x")
    found = f.validate_input "b"
    assert found.first==f.custom_message
    found = f.validate_input "012340"
    assert found.empty?
  end
  test 'prepend nested module type' do
    f = FieldValidatorRule.new(:model_field_uid=>"prod_uid",:regex=>"123",:custom_message=>"c")
    expected = "#{CoreModule::PRODUCT.label}: #{f.custom_message}"
    found = f.validate_field Product.new(:unique_identifier=>"x"), true
    assert expected==found.first
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

  test 'regex with numeric field' do 
    f = FieldValidatorRule.new(:model_field_uid=>"delln_line_number",:regex=>"12")
    d = DeliveryLine.new(:line_number=>12)
    assert f.validate_field(d).empty?
    d.line_number = 13
    assert f.validate_field(d).size==1
  end
  test 'regex validation' do 
    f = FieldValidatorRule.new(:model_field_uid=>"ord_ord_num")
    f.regex = "^abc"
    expected_message = "#{ModelField.find_by_uid(:ord_ord_num).label} must match expression #{f.regex}."
    o = Order.new(:order_number=>"abc")
    assert f.validate_field(o).empty?
    o.order_number= "def"
    msg = f.validate_field(o)
    assert msg.first==expected_message, "Expected #{expected_message}, got #{msg.to_s}"
    o.order_number= ""
    assert f.validate_field(o).empty? #not required so should pass
    f.regex=""
    assert f.validate_field(o).empty? #don't try to validate if regex is blank
    o.order_number = "fail"
  end

  test "Custom Message" do
    p = Product.new(:unique_identifier=>"123")
    f = FieldValidatorRule.new(:regex=>"fail",:model_field_uid=>"prod_uid",:custom_message=>"My message")
    msg = f.validate_field(p)
    assert msg.first==f.custom_message, "Expected #{f.custom_message}, got #{msg}"
  end
end
