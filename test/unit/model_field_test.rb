require 'test_helper'

class ModelFieldTest < ActiveSupport::TestCase
  
  test "test find by uid" do
    uid = "Product-name"
    mf = ModelField.find_by_uid uid
    assert mf.field_name == :name, "Should have found model field with name \"name\""
    assert mf.label == "Name", "Label should have been Name, was \"#{mf.label}\"."
    assert mf.model == CoreModule::PRODUCT.class_name.to_sym, "Should have had model #{CoreModule::PRODUCT.class_name} had #{mf.model}"
  end
  
  test "find by module type" do 
    mfs = ModelField.find_by_module_type CoreModule::PRODUCT.class_name.to_sym
    assert mfs.length > 0, "Should have returned multiple product fields."
    mfs.each {|m| assert m.model==CoreModule::PRODUCT.class_name.to_sym, "Should have had model #{CoreModule::PRODUCT.class_name} had #{m.model}"}
  end
  
  test "find_by_module_type_and_field_name" do
    mf = ModelField.find_by_module_type_and_field_name CoreModule::ORDER.class_name.to_sym, :order_number
    assert mf.model==CoreModule::ORDER.class_name.to_sym, "Model was #{mf.model} should have been #{CoreModule::ORDER.class_name}"
    assert mf.field_name==:order_number, "Name was #{mf.field_name} should have been :order_number"
  end
  
  test "data types" do
    mf = ModelField.find_by_module_type_and_field_name CoreModule::ORDER.class_name.to_sym, :order_number
    assert mf.data_type==:string, "Should find string for non-custom column, found #{mf.data_type}"
    #ModelField.reset_custom_fields #deal with fixtures not being loaded all the way
    mf = ModelField.find_by_module_type_and_custom_id CoreModule::PRODUCT.class_name.to_sym, 1
    assert mf.data_type==:boolean, "Should find boolean for custom column, found #{mf.data_type}"
  end
  
end