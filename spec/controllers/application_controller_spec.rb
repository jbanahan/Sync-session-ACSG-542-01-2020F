require 'spec_helper'

describe ApplicationController do

  describe :advanced_search do
    before :each do
      @u = Factory(:master_user)
      controller.stub(:current_user).and_return(@u)
    end
    it "should build default search if no search runs" do
      r = controller.advanced_search(CoreModule::PRODUCT)
      ss = @u.search_setups.where(:module_type=>'Product').first
      r.should == "/advanced_search#/#{ss.id}"
    end
    it "should redirect to advanced search with page" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!(:page=>3,:per_page=>100)
      r = controller.advanced_search(CoreModule::PRODUCT)
      r.should == "/advanced_search#/#{ss.id}/3"
    end
    it "should redirect to advanced search without page" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT)
      r.should == "/advanced_search#/#{ss.id}"
    end
    it "should redirect to advanced search if force_search is set to true" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!

      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      f.search_runs.create!

      other_module = Factory(:search_setup,:module_type=>'OfficialTariff',:user=>@u)
      other_module.search_runs.create!

      #make sure the search setup run is older
      SearchRun.connection.execute("UPDATE search_runs SET last_accessed = '2010-01-01 11:00' where id = #{sr.id}")
      r = controller.advanced_search(CoreModule::PRODUCT,true) 
      r.should == "/advanced_search#/#{ss.id}"
    end
    it "should redirect to most recent search run" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!
      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      fsr = f.search_runs.create!
      #make sure the search setup run is older
      SearchRun.connection.execute("UPDATE search_runs SET last_accessed = '2010-01-01 11:00' where id = #{sr.id}")
      r = controller.advanced_search(CoreModule::PRODUCT) 
      r.should == "/imported_files/show_angular#/#{f.id}"
    end
    it "should redirect to imported file with page" do
      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      fsr = f.search_runs.create!(:page=>7)
      r = controller.advanced_search(CoreModule::PRODUCT) 
      r.should == "/imported_files/show_angular#/#{f.id}/7"
    end
    it "should redirect to imported file without page" do
      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      fsr = f.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT) 
      r.should == "/imported_files/show_angular#/#{f.id}"
    end
    it "should redirect to custom file" do
      f = Factory(:custom_file,:uploaded_by=>@u,:module_type=>'Product')
      fsr = f.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT) 
      r.should == "/custom_files/#{f.id}"
    end
  end
  describe :strip_uri_params do
    it "should remove specified parameters from a URI string" do
      uri = "http://www.test.com/file.html?id=1&k=2&val[nested]=2#hash"
      r = controller.strip_uri_params uri, "id"
      r.should == "http://www.test.com/file.html?k=2&val[nested]=2#hash"
    end

    it "should not leave a dangling ? if query string is blank" do
      uri = "http://www.test.com/?k=2"
      r = controller.strip_uri_params uri, "k"
      r.should == "http://www.test.com/"
    end

    it "should handle blank query strings" do
      uri = "http://www.test.com"
      r = controller.strip_uri_params uri, "k"
      r.should == "http://www.test.com"
    end

    it "should handle missing keys" do
      uri = "http://www.test.com"
      r = controller.strip_uri_params uri
      r.should == "http://www.test.com"
    end
  end

end
