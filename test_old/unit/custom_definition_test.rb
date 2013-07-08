require 'test_helper'

class CustomDefinitionTest < ActiveSupport::TestCase

  test "default value - integer" do
    expected = 99
    cd = CustomDefinition.create!(:module_type=>"Order",:label=>"x",:data_type=>"integer",:default_value=>expected.to_s)
    o = Order.new
    cv = o.get_custom_value cd
    assert cv.value==expected
  end
  test "default value" do 
    expected = "ABCDEF"
    cd = CustomDefinition.create!(:module_type=>"Order",:label=>"x",:data_type=>"string",:default_value=>expected)
    o = Order.new
    cv = o.get_custom_value cd
    assert cv.value==expected
  end

  test "model_field_uid" do 
    cd = CustomDefinition.create!(:module_type=>"Order",:label=>"x",:data_type=>"date")
    assert cd.model_field_uid == "*cf_#{cd.id}", "Expected *cf_#{cd.id}, got #{cd.model_field_uid}"
  end

  test "date" do
    cd = CustomDefinition.new(:module_type=>"Order", :label=>"x",:data_type=>"date")
		assert cd.date?, "If data_type is \"date\" .date? should have been true"
		cd.data_type = "integer"
		assert !cd.date?, "If data_type is not \"date\" .date? should have been false"
  end
	
	test "can edit & can view" do #testing in the same test because they're the same for now
	  cd = CustomDefinition.new #don't need anything set
		u = User.find(1) #master user
		assert u.company.master?, "Setup check: should be master company"
		assert cd.can_edit?(u) && cd.can_view?(u), "Master user should be able to edit & view"
		u = User.find(2) #not master user
		assert !u.company.master, "Setup check: should not be master company"
		assert !cd.can_edit?(u) && !cd.can_view?(u), "Non-master user should not be able to edit or view"
	end
end
