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

      too_old.search_runs.create!(:last_accessed=>3.days.ago,:user_id=>@u.id)
      find_me.search_runs.create!(:last_accessed=>2.days.ago,:user_id=>@u.id)
      wrong_module.search_runs.create!(:last_accessed=>1.day.ago,:user_id=>@u.id)
      wrong_user.search_runs.create!(:last_accessed=>1.day.ago,:user_id=>wrong_user.user_id)

      SearchRun.find_last_run(@u,CoreModule::PRODUCT).should == find_me.search_runs.first
    end
    it "should not be read only" do
      find_me = Factory(:search_setup,:user=>@u,:module_type=>"Product")
      find_me.touch
      SearchRun.find_last_run(@u,CoreModule::PRODUCT).should_not be_readonly
    end
  end
  describe :parent do
    before :each do
      @cf = Factory(:custom_file)
    end
    it "should return search setup if it exists" do
      ss = Factory(:search_setup)
      im = Factory(:imported_file)
      sr = SearchRun.create(:search_setup_id=>ss.id,:imported_file_id=>im.id,:custom_file_id=>@cf.id)
      sr.parent.should == ss
    end
    it "should return imported_file if it exists and search setup doesn't" do
      im = Factory(:imported_file)
      sr = SearchRun.create(:imported_file_id=>im.id,:custom_file_id=>@cf.id)
      sr.parent.should == im
    end
    it "should return custom_file if it exists and search_setup/imported_file don't" do
      sr = SearchRun.create(:custom_file_id=>@cf.id)
      sr.parent.should == @cf 
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
      sr = ss.search_runs.create!
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
end
