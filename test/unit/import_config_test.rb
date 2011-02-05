require 'test_helper'

class ImportConfigTest < ActiveSupport::TestCase
  
  test "order number validation" do
    ic = ImportConfig.new(:name=>'test')
    ic.model_type = CoreModule::ORDER.class_name
    ic.import_config_mappings.build({:model_field_uid => ModelField.find_by_uid("ord_ord_date").uid,
        :column_rank => 1})
    assert !ic.save, "should fail to save on validations"
    found_order_number = false
    ic.errors[:base].each do |m|
      found_order_number = found_order_number || m == "All order mappings must contain the Order Number field." 
    end
    assert found_order_number, "Did not find the order number error message." 
  end
  
  test "order is valid without any mappings" do
    ic = ImportConfig.new(:name=>'test',:file_type=>'csv')
    ic.model_type = CoreModule::ORDER.class_name
    assert ic.valid?, "Didn't validate"
  end
  
  test "good order save with mappings" do
    ic = ImportConfig.new(:name=>'test',:file_type=>'csv')
    ic.model_type = CoreModule::ORDER.class_name
    ic.file_type = 'text/csv'
    col = 1
    ModelField::MODEL_FIELDS[CoreModule::ORDER.class_name.to_sym].values.each do |mf|
      ic.import_config_mappings.build({:model_field_uid => mf.uid, :column_rank => col})
      col += 1
    end
    assert ic.save, "Did not save properly: #{ic.errors.full_messages.to_s}"
  end
  
  test "order mappings with details must have product" do
    ic = ImportConfig.new(:name=>'test',:file_type=>'csv')
    ic.model_type = CoreModule::ORDER.class_name
    ic.import_config_mappings.build({:model_field_uid => ModelField.find_by_uid("ord_ord_num").uid,
        :column_rank => 1})
    
    #having the detail field "ordered_qty" should trigger the validation for the product_id    
    ic.import_config_mappings.build({:model_field_uid => ModelField.find_by_uid("ordln_ordered_qty").uid,
        :column_rank => 2})
    assert !ic.valid?, "should fail to save on validations"
    found_error = false
    assert ic.errors[:base].include?("All order mappings that have line level values must have the Product Unique Identifier."),
      "Did not find the error message."
  end
end

