require 'test_helper'

class CustomValueTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "uniqueness" do
    base = CustomValue.create!(:custom_definition => CustomDefinition.first, :customizable_id => 1000,
      :customizable_type => "Order")
    n = CustomValue.new(:custom_definition => base.custom_definition, :customizable_id => 1000,
      :customizable_type => "Order")
    assert !n.save, "Should have failed on dup record"
    n = CustomValue.new(:custom_definition => CustomDefinition.create!(:label=>"x", :module_type=>"Shipment",:data_type=>"String"), :customizable_id => 1000,
      :customizable_type => "Order")
    assert n.save, "Should have passed with different custom_definition_id"
    n = CustomValue.new(:custom_definition => base.custom_definition, :customizable_id => 1001,
      :customizable_type => "Order")
    assert n.save, "Should have passed with different customizable_id"
    n = CustomValue.new(:custom_definition => base.custom_definition, :customizable_id => 1000,
      :customizable_type => "Shipment")
    assert n.save, "Should have passed with different customizable_type"
    assert base.save, "Should be able to re-save."
  end
  
  test "string value" do
    d = CustomDefinition.create!(:data_type => "string", :label=>"x", :module_type => "Order")
    c = Order.first.custom_values.build(:custom_definition => d, :value => "my string")
    c.save!
    v = CustomValue.find(c.id).value
    assert v == "my string", "Did not retrieve from database properly. Should have been \"my string\" was #{v}"
  end
	
	test "integer value" do
	  d = CustomDefinition.create!(:data_type => "integer", :label=>"x", :module_type => "Order")
		c = Order.first.custom_values.build(:custom_definition => d, :value => 100)
		c.save!
		v = CustomValue.find(c.id).value
		assert v = 100, "Did not retrieve from database properly.  Should have been 100, was #{v}"
	end 
end
