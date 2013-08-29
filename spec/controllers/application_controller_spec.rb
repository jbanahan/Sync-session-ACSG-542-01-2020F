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

  describe :force_logout do 
    it "should destroy the UserSession" do
      session = double("UserSession")
      UserSession.should_receive(:find).and_return session
      session.should_receive(:destroy)
      controller.force_logout
    end

    it "should handle non-logged in users" do
      UserSession.should_receive(:find).and_return nil
      controller.force_logout
    end
  end

  describe :force_reset do 

    # Create an anonymous rspec controller, allows testing only the
    # filter mentioned in it
    controller do
      before_filter :force_reset

      def show
        render :text => "Rendered"
      end
    end

    before :each do 
      @u = Factory(:master_user)
      activate_authlogic
      UserSession.create! @u
      # Since we're using an anonymous controller we also need to define a route
      # for the password resets..ideally we'd be able to use the full rails routes
      # but I'm not sure how
      @routes.draw {
        resources :anonymous
        resources :password_resets
      }
    end

    it "should not do anything when a user is logged in and doesn't have password reset forced" do
      get :show, :id => 1
      response.code.should eq "200"
      response.body.should == "Rendered"
    end

    it "should not do anything if the user was not logged in" do
      controller.stub(:logged_in?).and_return false
      get :show, :id => 1
      response.code.should eq "200"
    end

    it "should redirect to password reset page if user has password reset checked" do
      @u.update_attributes password_reset: true
      controller.should_receive(:force_logout)
      User.any_instance.should_receive(:reset_password_prep)
      User.any_instance.stub(:perishable_token).and_return "ABC"
      get :show, :id => 1
      response.should redirect_to edit_password_reset_path "ABC"
    end
  end

end
