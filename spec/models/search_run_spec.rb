require 'spec_helper'

describe SearchRun do
  before :each do
    @u = Factory(:master_user)
  end
  describe "find_last_run" do
    it "should find newest for module & user" do
      find_me = Factory(:search_setup,:user=>@u,:module_type=>"Product")
      too_old = Factory(:search_setup,:user=>@u,:module_type=>"Product")
      wrong_module = Factory(:search_setup,:user=>@u,:module_type=>"Order")
      wrong_user = Factory(:search_setup,:module_type=>"Product")

      too_old.create_search_run(:last_accessed=>3.days.ago,:user_id=>@u.id)
      find_me.create_search_run(:last_accessed=>2.days.ago,:user_id=>@u.id)
      wrong_module.create_search_run(:last_accessed=>1.day.ago,:user_id=>@u.id)
      wrong_user.create_search_run(:last_accessed=>1.day.ago,:user_id=>wrong_user.user_id)

      SearchRun.find_last_run(@u,CoreModule::PRODUCT).should == find_me.search_run
    end
    it "should not be read only" do
      find_me = Factory(:search_setup,:user=>@u,:module_type=>"Product")
      find_me.touch
      SearchRun.find_last_run(@u,CoreModule::PRODUCT).should_not be_readonly
    end
  end
  context "navigation" do
    it "should step" do
      prods = []
      3.times do |c|
        prods << Factory(:product,:unique_identifier=>"bs_#{c}")
      end

      ss = Factory(:search_setup,:module_type=>"Product",:user=>@u)
      ss.sort_criterions.create!(:model_field_uid=>:prod_uid)

      ss.touch #creates search run

      sr = SearchRun.find_last_run @u, CoreModule::PRODUCT

      sr.current_object.should == prods[0]
      sr.move_forward
      sr.current_object.should == prods[1]
      sr.move_back
      sr.current_object.should == prods[0]
      sr.previous_object.should == nil
      sr.next_object.should == prods[1]
      sr.next_object.should == prods[1] #next_object doesn't move cursor so repeated calls should have same value
      sr.current_id.should == prods[0].id
      sr.move_forward
      sr.move_forward
      sr.current_object.should == prods[2]
      sr.next_object.should == nil
    end
  end
  describe "all_objects / total_objects" do
    before :each do
      @p1 = Factory(:product)
      @p2 = Factory(:product)
      @p3 = Factory(:product)
    end
    it "should find based on search_setup" do
      ss = Factory(:search_setup,:module_type=>"Product",:user=>@u)
      sr = ss.create_search_run
      sr.all_objects.should == [@p1,@p2,@p3]
      sr.total_objects.should == 3
    end
    it "should find based on imported_file" do
      fir = Factory(:file_import_result,:imported_file=>Factory(:imported_file,:module_type=>"Product"))
      [@p1,@p2].each {|p| fir.change_records.create!(:recordable_id=>p.id,:recordable_type=>"Product")}
      sr = fir.imported_file.search_runs.create!
      sr.all_objects.should == [@p1,@p2]
      sr.total_objects.should == 2
    end
    it "should find based on custom file" do
      cf = Factory(:custom_file)
      [@p2,@p3].each {|p| cf.custom_file_records.create!(:linked_object_id=>p.id,:linked_object_type=>"Product")}
      sr = cf.search_runs.create!
      sr.all_objects.should == [@p2,@p3]
      sr.total_objects.should == 2
    end
  end
  describe :reset_cursor do
    it "should clear cursor fields" do
      s = SearchRun.new(:position=>99,:result_cache=>'1,2,3',:starting_cache_position=>3)
      s.reset_cursor
      s.position.should be_nil
      s.result_cache.should be_nil
      s.starting_cache_position.should be_nil
    end
  end
end
