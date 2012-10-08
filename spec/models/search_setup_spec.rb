require 'spec_helper'

describe SearchSetup do
  describe "uploadable?" do
    #there are quite a few tests for this in the old test unit structure
    it 'should always reject ENTRY' do
      ss = Factory(:search_setup,:module_type=>'Entry')
      msgs = []
      ss.uploadable?(msgs).should be_false
      msgs.should have(1).item
      msgs.first.should == "Upload functionality is not available for Entries."
    end
    it 'should always reject BROKER_INVOICE' do
      ss = Factory(:search_setup,:module_type=>'BrokerInvoice')
      msgs = []
      ss.uploadable?(msgs).should be_false
      msgs.should have(1).item
      msgs.first.should == "Upload functionality is not available for Invoices."
    end
    it "should reject PRODUCT for non-master" do
      u = Factory(:importer_user,:product_edit=>true,:product_view=>true)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>u)
      msgs = []
      ss.uploadable?(msgs).should be_false
      msgs.first.include?("Only users from the master company can upload products.").should be_true
    end
  end
  describe :give_to do
    before :each do
      @u = Factory(:user,:first_name=>"A",:last_name=>"B")
      @u2 = Factory(:user)
      @s = SearchSetup.create!(:name=>"X",:module_type=>"Product",:user_id=>@u.id)
    end
    it "should copy to another user" do
      @s.give_to @u2
      d = SearchSetup.find_by_user_id @u2.id
      d.name.should == "X (From #{@u.full_name})"
      d.id.should_not be_nil
      @s.reload
      @s.name.should == "X" #we shouldn't modify the original object
    end
  end
  describe :deep_copy do
    before :each do 
      @u = Factory(:user)
      @s = SearchSetup.create!(:name=>"ABC",:module_type=>"Order",:user=>@u,:simple=>false,:download_format=>'csv',:include_links=>true)
    end
    it "should copy basic search setup" do
      d = @s.deep_copy "new"
      d.id.should_not be_nil
      d.id.should_not == @s.id
      d.name.should == "new"
      d.module_type.should == "Order"
      d.user.should == @u
      d.simple.should be_false
      d.download_format.should == 'csv'
      d.include_links.should be_true
    end
    it "should copy parameters" do
      @s.search_criterions.create!(:model_field_uid=>'a',:value=>'x',:operator=>'y',:status_rule_id=>1,:custom_definition_id=>2)
      d = @s.deep_copy "new"
      d.should have(1).search_criterions
      sc = d.search_criterions.first
      sc.model_field_uid.should == 'a'
      sc.value.should == 'x'
      sc.operator.should == 'y'
      sc.status_rule_id.should == 1
      sc.custom_definition_id.should == 2
    end
    it "should copy columns" do
      @s.search_columns.create!(:model_field_uid=>'a',:rank=>7,:custom_definition_id=>9)
      d = @s.deep_copy "new"
      d.should have(1).search_column
      sc = d.search_columns.first
      sc.model_field_uid.should == 'a'
      sc.rank.should == 7
      sc.custom_definition_id.should == 9
    end
    it "should copy sorts" do
      @s.sort_criterions.create!(:model_field_uid=>'a',:rank=>5,:custom_definition_id=>2,:descending=>true)
      d = @s.deep_copy "new"
      d.should have(1).sort_criterions
      sc = d.sort_criterions.first
      sc.model_field_uid.should == 'a'
      sc.rank.should == 5
      sc.custom_definition_id.should == 2
      sc.should be_descending
    end
    it "should not copy schedules" do
      @s.search_schedules.create!
      d = @s.deep_copy "new"
      d.search_schedules.should be_empty
    end
  end
end
