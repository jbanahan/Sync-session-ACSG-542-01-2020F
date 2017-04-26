require 'spec_helper'

describe ApplicationController do

  describe "advanced_search" do
    before :each do
      @u = Factory(:master_user)
      allow(controller).to receive(:current_user).and_return(@u)
    end
    it "should build default search if no search runs" do
      r = controller.advanced_search(CoreModule::PRODUCT)
      ss = @u.search_setups.where(:module_type=>'Product').first
      expect(r).to eq("/advanced_search#/#{ss.id}")
    end
    it "should redirect to advanced search with page" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!(:page=>3,:per_page=>100)
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/advanced_search#/#{ss.id}/3")
    end
    it "should redirect to advanced search without page" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/advanced_search#/#{ss.id}")
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
      expect(r).to eq("/advanced_search#/#{ss.id}")
    end
    it "should redirect to most recent search run" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!
      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      fsr = f.search_runs.create!
      #make sure the search setup run is older
      SearchRun.connection.execute("UPDATE search_runs SET last_accessed = '2010-01-01 11:00' where id = #{sr.id}")
      r = controller.advanced_search(CoreModule::PRODUCT) 
      expect(r).to eq("/imported_files/show_angular#/#{f.id}")
    end
    it "should redirect to imported file with page" do
      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      fsr = f.search_runs.create!(:page=>7)
      r = controller.advanced_search(CoreModule::PRODUCT) 
      expect(r).to eq("/imported_files/show_angular#/#{f.id}/7")
    end
    it "should redirect to imported file without page" do
      f = Factory(:imported_file,:module_type=>'Product',:user=>@u)
      fsr = f.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT) 
      expect(r).to eq("/imported_files/show_angular#/#{f.id}")
    end
    it "should redirect to custom file" do
      f = Factory(:custom_file,:uploaded_by=>@u,:module_type=>'Product')
      fsr = f.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT) 
      expect(r).to eq("/custom_files/#{f.id}")
    end
    it "inserts clearSelection parameter if instructed" do
      ss = Factory(:search_setup,:module_type=>'Product',:user=>@u)
      sr = ss.search_runs.create!(:page=>3,:per_page=>100)
      r = controller.advanced_search(CoreModule::PRODUCT, false, true)
      expect(r).to eq("/advanced_search#/#{ss.id}/3?clearSelection=true")
    end
  end
  describe "strip_uri_params" do
    it "should remove specified parameters from a URI string" do
      uri = "http://www.test.com/file.html?id=1&k=2&val[nested]=2#hash"
      r = controller.strip_uri_params uri, "id"
      expect(r).to eq("http://www.test.com/file.html?k=2&val[nested]=2#hash")
    end

    it "should not leave a dangling ? if query string is blank" do
      uri = "http://www.test.com/?k=2"
      r = controller.strip_uri_params uri, "k"
      expect(r).to eq("http://www.test.com/")
    end

    it "should handle blank query strings" do
      uri = "http://www.test.com"
      r = controller.strip_uri_params uri, "k"
      expect(r).to eq("http://www.test.com")
    end

    it "should handle missing keys" do
      uri = "http://www.test.com"
      r = controller.strip_uri_params uri
      expect(r).to eq("http://www.test.com")
    end
  end

  describe "force_reset" do 

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

      sign_in_as @u
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
      expect(response.code).to eq "200"
      expect(response.body).to eq("Rendered")
    end

    it "should not do anything if the user was not logged in" do
      allow(controller).to receive(:signed_in?).and_return false
      get :show, :id => 1
      expect(response.code).to eq "200"
    end

    it "should redirect to password reset page if user has password reset checked" do
      @u.update_attributes password_reset: true
      get :show, :id => 1
      # The reset should have used the forgot_password! method which sets a confirmation
      # token, if the redirect points the user to the same confirmation token as
      # what's set in the current user, then we're good to go.
      expect(response).to redirect_to edit_password_reset_path controller.current_user.confirmation_token
    end

    it "should display a password expired message if password_expired is set" do
      @u.update_attributes password_reset: true, password_expired: true

      get :show, :id => 1
      expect(response).to redirect_to edit_password_reset_path controller.current_user.confirmation_token
      expect(flash[:warning]).to include("Your password has expired. Please select a new password.")
    end
  end

  describe "set_x_frame_options_header" do
    # Create an anonymous rspec controller, allows testing only the
    # filter mentioned in it
    controller do
      before_filter :set_x_frame_options_header

      def show
        render :text => "Rendered"
      end
    end

    before :each do 
      @u = Factory(:master_user)

      sign_in_as @u
      @routes.draw {
        resources :anonymous
      }
    end

    it "should set X-Frame Options" do
      get :show, :id => 1
      expect(response.headers['X-Frame-Options']).to eq "SAMEORIGIN"
    end
  end

  describe "set_x_frame_options_header" do
    # Create an anonymous rspec controller, allows testing only the
    # filter mentioned in it
    controller do
      before_filter :set_x_frame_options_header

      def show
        render :text => "Rendered"
      end
    end

    before :each do 
      @u = Factory(:master_user)
      sign_in_as @u
      @routes.draw {
        resources :anonymous
      }
    end

    it "should set X-Frame Options" do
      get :show, :id => 1
      expect(response.headers['X-Frame-Options']).to eq "SAMEORIGIN"
    end
  end

  describe "set_csrf_cookie" do
    controller do
      after_filter :set_csrf_cookie

      def show
        render :text => "Rendered"
      end

      def protect_against_forgery?
        true
      end
    end

    before :each do 
      @u = Factory(:master_user)
      sign_in_as @u
      @routes.draw {
        resources :anonymous
      }
    end

    it "should set csrf cookie" do
      expect(controller).to receive(:form_authenticity_token).and_return "test"
      get :show, :id => 1
      expect(cookies['XSRF-TOKEN']).to eq "test"
    end
  end

  describe "verified_request?" do
    controller do
      protect_from_forgery

      def destroy
        render :text => "Rendered"
      end

      def protect_against_forgery?
        # This is off by default in test
        true
      end
    end

    before :each do 
      @u = Factory(:master_user)
      sign_in_as @u
      @routes.draw {
        resources :anonymous
      }
    end

    it "verifies requests with a valid X-XSRF-Token" do
      allow(controller).to receive(:form_authenticity_token).and_return "testing"
      request.env['X-XSRF-Token'] = "testing"
      post :destroy, :id => 1
    end
  end

  describe "current_user" do
    controller do
      def show 
        render :text => current_user.username
      end
    end

    before :each do
      @routes.draw {
        resources :anonymous
      }
    end

    it "supplies logged in user as current_user" do
      u = Factory(:user)
      sign_in_as u
      get :show, :id => 1
      expect(response.body).to eq u.username
    end

    it "delegates current_user to the user set in run_as" do
      u = Factory(:user)
      run_as = Factory(:user, run_as: u)
      sign_in_as u
      u.run_as = run_as
      u.save!

      get :show, :id => 1
      expect(response.body).to eq run_as.username
      expect(assigns(:run_as_user)).to eq u
    end
  end

  describe "portal_redirect" do
    controller do
      def show 
        render :text => current_user.username
      end
    end

    before :each do
      @routes.draw {
        resources :anonymous
      }
    end

    it "should redirect to portal_redirect_path if not blank?" do
    
      allow_any_instance_of(User).to receive(:portal_redirect_path).and_return '/abc'
      u = Factory(:user)
      sign_in_as u

      get :show, id: 1

      expect(response).to redirect_to '/abc'

    end
    it "should not do anything if portal_redirect_path.blank?" do
      u = Factory(:user)
      sign_in_as u

      get :show, id: 1

      expect(response).to be_success
      expect(response.body).to eq u.username
    end
  end
end
