require 'test_helper'

class CoreModuleTest < ActiveSupport::TestCase
  test "find statusable" do
    expected_count = 1
    cms = CoreModule.find_statusable
    assert cms.length == expected_count, "Should have returned #{expected_count} core modules, returned #{cms.length}"
    assert cms.include?(CoreModule::PRODUCT)
  end
  
  test "find file_formatable" do
    expected_count = 2
    cms = CoreModule.find_file_formatable
    assert cms.length == expected_count, "Should have return #{expected_count} core modules, returned #{cms.length}"
    assert cms.include?(CoreModule::PRODUCT)
    assert cms.include?(CoreModule::ORDER) 
  end
  
  test "to_a_label_class with block" do
    expected_count = 2
    cms = CoreModule.to_a_label_class {|c| c.class_name[0,5]=="Order"}
    assert cms.length == expected_count, "Should have return #{expected_count} core modules, returned #{cms.length}"
    assert cms.include?([CoreModule::ORDER_LINE.label,CoreModule::ORDER_LINE.class_name])
    assert cms.include?([CoreModule::ORDER.label,CoreModule::ORDER.class_name])
  end
  
  test "to_a_label_class without block" do
    expected_count = CoreModule::CORE_MODULES.length
    cms = CoreModule.to_a_label_class
    assert cms.length == expected_count, "Should have returned #{expected_count}, returned #{cms.length}"
    assert cms.include?([CoreModule::ORDER.label,CoreModule::ORDER.class_name])
  end
  
  test "new object" do
    CoreModule::CORE_MODULES.each do |cm|
      o = cm.new_object
      assert o.class.to_s == cm.class_name.to_s, "Created #{o.class.to_s}, expected #{cm.class_name.to_s}"
    end
  end
end