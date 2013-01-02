require 'spec_helper'

describe Region do
  context :default_scope do
    it "should sort by name" do
      r1 = Factory(:region,:name=>"B")
      r2 = Factory(:region,:name=>"A")
      Region.where("1").to_a.should == [r2,r1]
    end
  end
  context :destroy do
    it "should destroy associated report objects on destroy based on class count model_field_uid" do
      r = Factory(:region)
      uid = 
      col = Factory(:search_column,:model_field_uid=>ModelField.uid_for_region(r,"x"))
      srch = Factory(:search_criterion,:model_field_uid=>ModelField.uid_for_region(r,"y"))
      srt = Factory(:sort_criterion,:model_field_uid=>ModelField.uid_for_region(r,"z"))
      r.destroy
      SearchColumn.exists?(col.id).should be_false
      SearchCriterion.exists?(srch.id).should be_false
      SortCriterion.exists?(srt.id).should be_false
    end
    it "should remove itself from ModelFields" do
      r = Region.create!(:name=>'x')
      ModelField.find_by_region(r).should have(1).model_field
      r.destroy
      ModelField.find_by_region(r).should have(0).model_field
    end
  end
  context :create do
    it "should reload model fields and include itself" do
      r = Region.create!(:name=>'x')
      ModelField.find_by_region(r).should have(1).model_field
    end
  end
end
