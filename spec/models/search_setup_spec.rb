require 'spec_helper'

describe SearchSetup do
  describe :result_keys do
    it "should initialize query" do
      SearchQuery.any_instance.should_receive(:result_keys).and_return "X"
      SearchSetup.new.result_keys.should == "X"
    end
  end
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
  describe "downloadable?" do
    it "is downloadable if there are search criterions" do
      ss = Factory(:search_criterion, search_setup: Factory(:search_setup)).search_setup
      expect(ss.downloadable?).to be_true
    end

    it "is not downloadable if there are no search criterions" do
      errors = []
      expect(Factory(:search_setup).downloadable? errors).to be_false
      expect(errors).to eq ["You must add at least one Parameter to your search setup before downloading a search."]
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
    it "should copy to another user including schedules" do
      @s.search_schedules.build
      @s.save
      @s.give_to @u2, true
      
      d = SearchSetup.find_by_user_id @u2.id
      d.name.should == "X (From #{@u.full_name})"
      d.search_schedules.should have(1).item
    end
    it "should strip existing '(From X)' values from search names" do
      @s.update_attributes :name => "Search (From David St. Hubbins) (From Nigel Tufnel)"
      @s.give_to @u2
      d = SearchSetup.find_by_user_id @u2.id
      d.name.should == "Search (From #{@u.full_name})"
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
    it "should copy schedules when told to do so" do
      @s.search_schedules.create!
      d = @s.deep_copy "new", true
      d.search_schedules.should have(1).item
    end
  end
  describe "values" do
    it "should work for all model fields in SELECT" do
      r = Factory(:region)
      r.countries << Factory(:country)
      ModelField.reload true
      CoreModule::CORE_MODULES.each do |cm|
        cm.klass.stub(:search_where).and_return("1=1")
        
        ss = SearchSetup.new(:module_type=>cm.class_name)
        cm.model_fields.keys.each_with_index do |mfid,i|
          ss.search_columns.build(:model_field_uid=>mfid,:rank=>i)
          ss.sort_criterions.build(:model_field_uid=>mfid,:rank=>i)
          ss.search_criterions.build(:model_field_uid=>mfid,:operator=>'null')
        end
        #just making sure each query executes without error
        SearchQuery.new(ss,User.new).execute
      end
    end
  end
  context :last_accessed do
    before :each do 
      @s = Factory :search_setup
    end

    it "should return the last_accessed time from an associated search run" do
      @s.last_accessed.should be_nil
      now = Time.zone.now
      @s.search_runs.build :last_accessed=>now
      @s.save

      @s.last_accessed.to_i == now.to_i
    end
  end
end
