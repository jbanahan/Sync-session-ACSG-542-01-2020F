require 'test_helper'

class ImportConfigTest < ActiveSupport::TestCase
  test "find model field" do 
    found = ImportConfig.find_model_field(:order,:order_number)
    assert found.field == :order_number, "Should have found order_number"
  end
  test "order number validation" do
    ic = ImportConfig.new(:name=>'test')
    ic.model_type = ImportConfig::MODEL_TYPES[:order]
    ic.import_config_mappings.build({:model_field_uid => ImportConfig.find_model_field(:order,:order_date).uid,
        :column => 1})
    assert !ic.save, "should fail to save on validations"
    found_order_number = false
    ic.errors[:base].each do |m|
      found_order_number = found_order_number || m == "All order mappings must contain the Order Number field." 
    end
    assert found_order_number, "Did not find the order number error message." 
  end
  
  test "order is valid without any mappings" do
    ic = ImportConfig.new(:name=>'test',:file_type=>'csv')
    ic.model_type = ImportConfig::MODEL_TYPES[:order]
    assert ic.valid?, "Didn't validate"
  end
  
  test "good order save with mappings" do
    ic = ImportConfig.new(:name=>'test',:file_type=>'csv')
    ic.model_type = ImportConfig::MODEL_TYPES[:order]
    ic.file_type = 'text/csv'
    col = 1
    ImportConfig::MODEL_FIELDS[:order].values.each do |mf|
      ic.import_config_mappings.build({:model_field_uid => mf.uid, :column => col})
      col += 1
    end
    assert ic.save, "Did not save properly: #{ic.errors.full_messages.to_s}"
  end
  
  test "order mappings with details must have product" do
    ic = ImportConfig.new(:name=>'test',:file_type=>'csv')
    ic.model_type = ImportConfig::MODEL_TYPES[:order]
    ic.import_config_mappings.build({:model_field_uid => ImportConfig.find_model_field(:order,:order_number).uid,
        :column => 1})
    
    #having the detail field "ordered_qty" should trigger the validation for the product_id    
    ic.import_config_mappings.build({:model_field_uid => ImportConfig.find_model_field(:order,:ordered_qty).uid,
        :column => 2})
    assert !ic.valid?, "should fail to save on validations"
    found_error = false
    assert ic.errors[:base].include?("All order mappings that have line level values must have the Product Unique Identifier."),
      "Did not find the error message."
  end
end

