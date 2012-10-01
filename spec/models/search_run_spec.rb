require 'spec_helper'

describe SearchRun do
  before :each do
    @p1 = Factory(:product)
    @p2 = Factory(:product)
    @p3 = Factory(:product)
    @u = Factory(:master_user)
  end
  describe "all_objects" do
    it "should find based on search_setup" do
      ss = Factory(:search_setup,:module_type=>"Product",:user=>@u)
      sr = ss.create_search_run
      sr.all_objects.should == [@p1,@p2,@p3]
    end
    it "should find based on imported_file" do
      fir = Factory(:file_import_result,:imported_file=>Factory(:imported_file,:module_type=>"Product"))
      [@p1,@p2].each {|p| fir.change_records.create!(:recordable_id=>p.id,:recordable_type=>"Product")}
      sr = fir.imported_file.search_runs.create!
      sr.all_objects.should == [@p1,@p2]
    end
    it "should find based on custom file" do
      cf = Factory(:custom_file)
      [@p2,@p3].each {|p| cf.custom_file_records.create!(:linked_object_id=>p.id,:linked_object_type=>"Product")}
      sr = cf.search_runs.create!
      sr.all_objects.should == [@p2,@p3]
    end
  end
end
