require 'spec_helper'

describe "CustomFieldSupport" do
  describe "update_custom_value"
    before :each do
      @cd = CustomDefinition.create!(:module_type=>"Shipment",:label=>"CX",:data_type=>"string") 
      @s = Factory(:shipment)
      @s.update_custom_value!(@cd,"x")
    end
    it 'should update a new custom value' do
      CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"x").customizable.should == @s
    end
    it 'should update an existing custom value' do
      @s.update_custom_value!(@cd,"y")
      CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"y").customizable.should == @s
    end
    it 'should update with a custom_value_id' do
      @s.update_custom_value!(@cd.id,"y")
      CustomValue.find_by_custom_definition_id_and_string_value(@cd.id,"y").customizable.should == @s
    end
end
