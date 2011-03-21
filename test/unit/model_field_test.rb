require 'test_helper'

class ModelFieldTest < ActiveSupport::TestCase
  
  test "test find by uid" do
    uid = "prod_name"
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
  
  test "find_by_module_type_and_uid" do
    mf = ModelField.find_by_module_type_and_uid CoreModule::ORDER.class_name.to_sym, :ord_ord_num
    assert mf.model==CoreModule::ORDER.class_name.to_sym, "Model was #{mf.model} should have been #{CoreModule::ORDER.class_name}"
    assert mf.field_name==:order_number, "Name was #{mf.field_name} should have been :order_number"
  end
  
  test "data types" do
    mf = ModelField.find_by_module_type_and_uid CoreModule::ORDER.class_name.to_sym, :ord_ord_num
    assert mf.data_type==:string, "Should find string for non-custom column, found #{mf.data_type}"
    mf = ModelField.find_by_module_type_and_custom_id CoreModule::PRODUCT.class_name.to_sym, 1
    assert mf.data_type==:boolean, "Should find boolean for custom column, found #{mf.data_type}"
    mf = ModelField.find_by_module_type_and_uid CoreModule::PRODUCT.class_name.to_sym, :prod_class_count
    assert mf.data_type==:integer, "Should find integer for column with data_type set in hash, found #{mf.data_type}"
  end
  
  test "order line product_uid import/export lambdas" do
    oline = Order.new(:order_number=>"olpuim",:vendor=>companies(:vendor)).order_lines.build(:line_number=>1)
    mf = ModelField.find_by_uid :ordln_puid
    p = companies(:vendor).vendor_products.first
    mf.process_import oline, p.unique_identifier
    oline.save!
    assert oline.errors.empty?, "Order line should not have had any errors. Errors: #{oline.errors.full_messages}"
    exp = mf.process_export(oline)
    assert exp==p.unique_identifier, "Export failed. Expected #{p.unique_identifier}, found: #{exp}"
  end
end
