describe ApplicationController do

  describe "advanced_search" do
    before :each do
      @u = FactoryBot(:master_user)
      allow(controller).to receive(:current_user).and_return(@u)
    end
    it "should build default search if no search runs" do
      r = controller.advanced_search(CoreModule::PRODUCT)
      ss = @u.search_setups.where(:module_type=>'Product').first
      expect(r).to eq("/advanced_search#!/#{ss.id}")
    end
    it "should redirect to advanced search with page" do
      ss = FactoryBot(:search_setup, :module_type=>'Product', :user=>@u)
      sr = ss.search_runs.create!(:page=>3, :per_page=>100)
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/advanced_search#!/#{ss.id}/3")
    end
    it "should redirect to advanced search without page" do
      ss = FactoryBot(:search_setup, :module_type=>'Product', :user=>@u)
      sr = ss.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/advanced_search#!/#{ss.id}")
    end
    it "should redirect to advanced search if force_search is set to true" do
      ss = FactoryBot(:search_setup, :module_type=>'Product', :user=>@u)
      sr = ss.search_runs.create!

      f = FactoryBot(:imported_file, :module_type=>'Product', :user=>@u)
      f.search_runs.create!

      other_module = FactoryBot(:search_setup, :module_type=>'OfficialTariff', :user=>@u)
      other_module.search_runs.create!

      # make sure the search setup run is older
      SearchRun.connection.execute("UPDATE search_runs SET last_accessed = '2010-01-01 11:00' where id = #{sr.id}")
      r = controller.advanced_search(CoreModule::PRODUCT, true)
      expect(r).to eq("/advanced_search#!/#{ss.id}")
    end
    it "should redirect to most recent search run" do
      ss = FactoryBot(:search_setup, :module_type=>'Product', :user=>@u)
      sr = ss.search_runs.create!
      f = FactoryBot(:imported_file, :module_type=>'Product', :user=>@u)
      fsr = f.search_runs.create!
      # make sure the search setup run is older
      SearchRun.connection.execute("UPDATE search_runs SET last_accessed = '2010-01-01 11:00' where id = #{sr.id}")
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/imported_files/show_angular#!/#{f.id}")
    end
    it "should redirect to imported file with page" do
      f = FactoryBot(:imported_file, :module_type=>'Product', :user=>@u)
      fsr = f.search_runs.create!(:page=>7)
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/imported_files/show_angular#!/#{f.id}/7")
    end
    it "should redirect to imported file without page" do
      f = FactoryBot(:imported_file, :module_type=>'Product', :user=>@u)
      fsr = f.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/imported_files/show_angular#!/#{f.id}")
    end
    it "should redirect to custom file" do
      f = FactoryBot(:custom_file, :uploaded_by=>@u, :module_type=>'Product')
      fsr = f.search_runs.create!
      r = controller.advanced_search(CoreModule::PRODUCT)
      expect(r).to eq("/custom_files/#{f.id}")
    end
    it "inserts clearSelection parameter if instructed" do
      ss = FactoryBot(:search_setup, :module_type=>'Product', :user=>@u)
      sr = ss.search_runs.create!(:page=>3, :per_page=>100)
      r = controller.advanced_search(CoreModule::PRODUCT, false, true)
      expect(r).to eq("/advanced_search#!/#{ss.id}/3?clearSelection=true")
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
      @u = FactoryBot(:master_user)

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
      @u.password_reset = true
      @u.save!

      get :show, :id => 1
      # The reset should have used the forgot_password! method which sets a confirmation
      # token, if the redirect points the user to the same confirmation token as
      # what's set in the current user, then we're good to go.
      expect(response).to redirect_to edit_password_reset_path controller.current_user.confirmation_token
    end

    it "should display a password expired message if password_expired is set" do
      @u.password_reset = true
      @u.password_expired = true
      @u.save!

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
      @u = FactoryBot(:master_user)

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
      @u = FactoryBot(:master_user)
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
      @u = FactoryBot(:master_user)
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
      @u = FactoryBot(:master_user)
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

  describe "validate_redirect" do

    let! (:master_setup) {
      stub_master_setup
    }

    it "returns redirect if valid" do
      expect(controller.validate_redirect("http://localhost/path/to/page")).to eq "http://localhost/path/to/page"
    end

    it "raises an error if redirect is to a different host" do
      expect { controller.validate_redirect("http://some.domain.com") }.to raise_error "Illegal Redirect"
    end

    it "does not error if no domain is given" do
      expect { controller.validate_redirect("/path/to/page.html") }.not_to raise_error
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
      u = FactoryBot(:user)
      sign_in_as u
      get :show, :id => 1
      expect(response.body).to eq u.username
    end

    it "delegates current_user to the user set in run_as" do
      u = FactoryBot(:user)
      run_as = FactoryBot(:user, run_as: u)
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
        render :text => "SHOW"
      end

      def index
        render text: "INDEX"
      end

      def create
        render text: "CREATE"
      end
    end

    before :each do
      @routes.draw {
        resources :anonymous
      }

      u = FactoryBot(:user)
      sign_in_as u
    end

    it "does nothing if portal_redirect_path is blank" do
      allow_any_instance_of(User).to receive(:portal_redirect_path).and_return nil
      get :show, id: 1
      expect(response).to be_success
      expect(response.body).to eq "SHOW"
    end

    it "does nothing if request path begins with portal_redirect_path" do
      allow_any_instance_of(User).to receive(:portal_redirect_path).and_return "/abc"
      controller.request.path = "/abc/rest/of/path"

      get :show, id: 1
      expect(response).to be_success
      expect(response.body).to eq "SHOW"
    end

    it "does nothing if combination of portal_redirect_path and request path is whitelisted" do
      allow_any_instance_of(User).to receive(:portal_redirect_path).and_return "/vendor_portal"

      controller.request.path = "/messages/1/read"
      get :show, id: 1
      expect(response).to be_success
      expect(response.body).to eq "SHOW"

      controller.request.path = "/messages/read_all"
      get :index
      expect(response).to be_success
      expect(response.body).to eq "INDEX"

      controller.request.path = "/messages/message_count"
      get :index
      expect(response).to be_success
      expect(response.body).to eq "INDEX"

      controller.request.path = "/messages"
      get :index
      expect(response).to be_success
      expect(response.body).to eq "INDEX"

      # same path, wrong method
      controller.request.path = "/messages"
      post :create
      expect(response).to redirect_to "/vendor_portal"

      controller.request.path = "/messages/1"
      get :show, id: 1
      expect(response).to be_success
      expect(response.body).to eq "SHOW"

      controller.request.path = "/users/email_new_message"
      post :create # Really ought to be a PUT, but that's the API
      expect(response).to be_success
      expect(response.body).to eq "CREATE"

      controller.request.path = "/announcements/index_for_user"
      get :index
      expect(response).to be_success
      expect(response.body).to eq "INDEX"

      controller.request.path = "/announcements/show_modal"
      get :show, id: 1
      expect(response).to be_success
      expect(response.body).to eq "SHOW"

      controller.request.path = "/user_manuals/1/download"
      get :show, id: 1
      expect(response).to be_success
      expect(response.body).to eq "SHOW"

      controller.request.path = "/user_manuals/for_referer"
      get :index
      expect(response).to be_success
      expect(response.body).to eq "INDEX"
    end

    it "redirects to portal_redirect_path otherwise" do
      allow_any_instance_of(User).to receive(:portal_redirect_path).and_return "/abc"
      controller.request.path = "cba/rest/of/path"

      get :show, id: 1
      expect(response).to redirect_to "/abc"
    end
  end

  describe "log_last_request_time" do
    # Create an anonymous rspec controller, allows testing only the
    # filter mentioned in it
    controller do
      before_filter :log_last_request_time

      def show
        render :text => "Rendered"
      end
    end

    let! (:user) {
      u = FactoryBot(:user)
      sign_in_as(u)
      u
    }

    before :each do
      @routes.draw {
        resources :anonymous
      }
    end

    it "sets last_request_at to current time and updates active days" do
      now = Time.zone.parse("2018-07-20 12:30")

      Timecop.freeze(now) { get :show, id: 1 }

      user.reload
      expect(user.last_request_at).to eq now
      expect(user.active_days).to eq 1
    end

    it "does not update the last request if it hasn't been over a minute since the previous request" do
      now = Time.zone.parse("2018-07-20 12:30")
      last_request = Time.zone.parse("2018-07-20 12:29:00")
      user.update_column :last_request_at, last_request

      Timecop.freeze(now) { get :show, id: 1 }
      user.reload
      expect(user.last_request_at).to eq last_request
    end

    it "does not update the active_days if a day has not passed since the previous request" do
      now = Time.zone.parse("2018-07-20 23:59:59")
      last_request = Time.zone.parse("2018-07-20 00:00:00")
      user.update_column :last_request_at, last_request

      Timecop.freeze(now) { get :show, id: 1 }
      user.reload
      expect(user.active_days).to eq 0
    end

    it "updates active_days if a day has passed since the previous request" do
      # Verify that we increment the days counter based on the date changing not a duration of time passing
      now = Time.zone.parse("2018-07-21 00:00:00")
      # We skip requests that aren't more than a minute apart...so make sure the last request is over a minute ago
      last_request = Time.zone.parse("2018-07-20 23:58:59")
      user.update_column :last_request_at, last_request

      Timecop.freeze(now) { get :show, id: 1 }
      user.reload
      expect(user.active_days).to eq 1
    end
  end

  describe "action_secure" do

    it "checks permission and fails if permission check returns false" do
      expect(subject).to receive(:error_redirect).with("You do not have permission to edit this object.")
      subject.action_secure(false, nil)
    end

    it "yields if permission check is true" do
      expect(subject).not_to receive(:error_redirect)
      yielded = false
      subject.action_secure(true, nil) { yielded = true }
      expect(yielded).to eq true
    end

    it "yields in db_lock if request is a mutable request type" do
      allow(request).to receive(:get?).and_return false
      object = FactoryBot(:product)

      expect(Lock).to receive(:db_lock).with(object).and_yield
      yielded = false
      subject.action_secure(true, object) { yielded = true }
      expect(yielded).to eq true
    end

    it "does not yield in db_lock if request is a nonmutable request type" do
      expect(request).to receive(:get?).and_return true
      object = FactoryBot(:product)

      expect(Lock).not_to receive(:db_lock)
      yielded = false
      subject.action_secure(true, object) { yielded = true }
      expect(yielded).to eq true
    end

    it "yields in db_lock if request is a nonmutable request type if forced" do
      expect(request).to receive(:get?).and_return true
      object = FactoryBot(:product)

      expect(Lock).to receive(:db_lock).with(object).and_yield
      yielded = false
      subject.action_secure(true, object, yield_in_db_lock: true) { yielded = true }
      expect(yielded).to eq true
    end

    it "does not yield in db_lock if object is not an ActiveRecord object" do
      expect(Lock).not_to receive(:db_lock)
      yielded = false
      subject.action_secure(true, "", yield_in_db_lock: true) { yielded = true }
      expect(yielded).to eq true
    end

    it "does not yield in db_lock if object is not persisted" do
      expect(Lock).not_to receive(:db_lock)
      yielded = false
      subject.action_secure(true, Product.new, yield_in_db_lock: true) { yielded = true }
      expect(yielded).to eq true
    end

    it "checks for locked objects" do
      p = Product.new
      expect(p).to receive(:locked?).and_return true
      expect(subject).to receive(:error_redirect).with "You cannot edit an object with a locked company."
      yielded = false
      subject.action_secure(true, p) { yielded = true }
      expect(yielded).to eq false
    end

    it "allows replacing default lock lambda" do
      p = Product.new
      expect(p).not_to receive(:locked?)
      expect(subject).not_to receive(:error_redirect)
      yielded = false
      subject.action_secure(true, p, {lock_lambda: lambda {|o| false} }) { yielded = true }
      expect(yielded).to eq true
    end

    it "allows bypassing lock check" do
      lock_check = false
      lock_lambda = lambda { |o| lock_check = true }
      yielded = false
      subject.action_secure(true, p, lock_check: false) { yielded = true }
      expect(yielded).to eq true
    end

    it "allows passing new module name" do
      p = Product.new
      expect(p).to receive(:locked?).and_return true
      expect(subject).to receive(:error_redirect).with "You cannot edit a My Product with a locked company."
      yielded = false
      subject.action_secure(true, p, module_name: "My Product") { yielded = true }
      expect(yielded).to eq false
    end
  end

  describe "group_secure" do
    before :each do
      @u = FactoryBot(:user)
      sign_in_as(@u)
      @u
    end

    it "yields if the user not is in the provided group" do
      group = Group.use_system_group("Some Group")
      @u.groups << group
      @u.save!

      result = false
      subject.group_secure("Some Group") { result = true }
      expect(result).to eq true
    end

    it "errors if the user is in the provided group" do
      group = Group.use_system_group("Some Group")

      expect(subject).to receive(:error_redirect).with "Only members of the 'Some Group' group can do this."

      result = false
      subject.group_secure("Some Group") { result = true }
      expect(result).to eq false
    end

    it "errors if the user is in the provided group, using provided custom error" do
      group = Group.use_system_group("Some Group")

      expect(subject).to receive(:error_redirect).with "Game over, man"

      result = false
      subject.group_secure("Some Group", alt_error_message:"Game over, man") { result = true }
      expect(result).to eq false
    end

    it "errors if we're dealing with a group that has not yet been set up" do
      expect(subject).to receive(:error_redirect).with "Only members of the 'Some Group' group can do this."

      result = false
      subject.group_secure("Some Group") { result = true }
      expect(result).to eq false

      # Should not create the group.
      group = Group.where(system_code:"Some Group").first
      expect(group).to be_nil
    end
  end
end
