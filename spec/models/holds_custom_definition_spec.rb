require 'spec_helper'

describe HoldsCustomDefinition do
  
  context :custom_definition do
    before :each do
      @cd = Factory(:custom_definition,:module_type=>"Product")
      ModelField.reset_custom_fields
      @cfid = "*cf_#{@cd.id}"
    end
    context "model_field_uid" do
      it "should set id" do
        [SearchColumn,SearchCriterion,SortCriterion].each do |k|
          sc = k.new
          sc.model_field_uid = @cfid
          sc.should be_custom_field
          sc.custom_definition_id.should == @cd.id
        end
      end
    end
    context "before_save" do
      it "should associate on save" do
        [:search_column,:search_criterion,:sort_criterion].each do |k|
          sc = Factory(k,:model_field_uid=>@cfid)
          sc.save!
          sc.custom_definition.should == @cd
        end
      end
    end
  end
end
