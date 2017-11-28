require 'spec_helper'

describe UsersController do
  before :each do
    @user = Factory(:user)
    sign_in_as @user
  end
  
  describe "create" do
    it "should create user with apostrophe in email address" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)
      u = {'username'=>"c'o@sample.com",'password'=>'pw12345','password_confirmation'=>'pw12345','email'=>"c'o@sample.com",
        'company_id'=>@user.company_id.to_s
      }
      expect {
        post :create, {'company_id'=>@user.company_id,'user'=>u}
      }.to change(User,:count).by(1)
      expect(response).to be_redirect
    end

    context "when copying an existing user" do
      before(:each) do
        @user.admin = true
        @copied_user = Factory(:user)
      end

      it "should add existing user's group memberships" do
        @copied_user.groups << gr_assigned_1 = Factory(:group)
        @copied_user.groups << gr_assigned_2 = Factory(:group)

        new_user_params = {username: "Fred", email: "fred@abc.com", company_id: @copied_user.company.id, password: "pw12345", password_confirmation: "pw12345",
                           group_ids: @copied_user.group_ids} 

        post :create, {company_id: @copied_user.company.id, user: new_user_params}
        new_user = User.last
        expect(User.count).to eq 3
        expect(new_user.groups.sort).to eq [gr_assigned_1, gr_assigned_2].sort
        expect(response).to be_redirect
      end

      it "should add existing user's search setups" do
        ss_assigned_1 = Factory(:search_setup, name: 'foo', user: @copied_user)
        ss_assigned_2 = Factory(:search_setup, name: 'bar', user: @copied_user)

        new_user_params = {username: "Fred", email: "fred@abc.com", company_id: @copied_user.company.id, password: "pw12345", password_confirmation: "pw12345"}
        post :create, {company_id: @copied_user.company.id, user: new_user_params, assigned_search_setup_ids: [ss_assigned_1.id, ss_assigned_2.id]}
        new_user = User.last

        expect(User.count).to eq 3
        expect(SearchSetup.count).to eq 4
        expect(new_user.search_setups.pluck(:name).sort).to eq ['bar', 'foo']
        expect(response).to be_redirect
      end

      it "should add existing user's custom reports" do
        cr_assigned_1 = Factory(:custom_report, name: 'foo', user: @copied_user)
        cr_assigned_2 = Factory(:custom_report, name: 'bar', user: @copied_user)

        new_user_params = {username: "Fred", email: "fred@abc.com", company_id: @copied_user.company.id, password: "pw12345", password_confirmation: "pw12345"}
        post :create, {company_id: @copied_user.company.id, user: new_user_params, assigned_custom_report_ids: [cr_assigned_1.id, cr_assigned_2.id]}
        new_user = User.last

        expect(User.count).to eq 3
        expect(CustomReport.count).to eq 4
        expect(new_user.custom_reports.pluck(:name).sort).to eq ['bar', 'foo']
        expect(response).to be_redirect
      end

      it "should not attempt to add search setups or custom reports if the the user fails to save" do
        ss_assigned_1 = Factory(:search_setup, name: 'foo', user: @copied_user)
        ss_assigned_2 = Factory(:search_setup, name: 'bar', user: @copied_user)
        cr_assigned_1 = Factory(:custom_report, name: 'foo', user: @copied_user)
        cr_assigned_2 = Factory(:custom_report, name: 'bar', user: @copied_user)

        new_user_params = {username: "Fred", email: "fred@abc.com", company_id: @copied_user.company.id} # missing password/confirmation
        post :create, {company_id: @copied_user.company.id, user: new_user_params, assigned_search_setup_ids: [ss_assigned_1.id, ss_assigned_2.id],
                       assigned_custom_report_ids: [cr_assigned_1.id, cr_assigned_2.id]}
      
        expect(SearchSetup.count).to eq 2
        expect(CustomReport.count).to eq 2
        expect(response).to render_template(:new)
      end

    end
  end

  describe "show_create_from_template" do
    before :each do
      @t = Factory(:user_template)
    end
    it "should only allow admins" do
      u = Factory(:user)
      sign_in_as u
      get :show_create_from_template, company_id: u.company_id
      expect(response).to be_redirect
      expect(assigns(:user_templates)).to be_nil
    end
    it "should assign user templates" do
      u = Factory(:admin_user)
      sign_in_as u
      get :show_create_from_template, company_id: u.company_id
      expect(response).to be_success
      expect(assigns(:user_templates).to_a).to eq [@t]
    end
  end

  describe "create_from_template" do
    before :each do
      @t = Factory(:user_template)
    end
    it "should only allow admins" do
      expect_any_instance_of(UserTemplate).not_to receive(:create_user!)
      u = Factory(:user)
      sign_in_as u
      post :create_from_template, {
        company_id: u.company_id, 
        user_template_id: @t.id,
        first_name: 'Joe', last_name: 'Smith',
        email: 'jsmith@sample.com',
        time_zone: 'Eastern Time (US & Canada)',
        notify_user: 'true'}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should create user based on template" do
      u = Factory(:admin_user)
      sign_in_as u
      expect_any_instance_of(UserTemplate).to receive(:create_user!).with(
        u.company,
        'Joe', 'Smith', 'jsmith@sample.com', 'jsmith@sample.com', 
        'Eastern Time (US & Canada)', 'true'
      )
      post :create_from_template, {
        company_id: u.company_id, 
        user_template_id: @t.id,
        first_name: 'Joe', last_name: 'Smith',
        email: 'jsmith@sample.com',
        time_zone: 'Eastern Time (US & Canada)',
        notify_user: 'true'}
      expect(response).to be_redirect
    end
  end

  describe "new" do
    context "with admin authorization" do
      before(:each) do
        @user.admin = true
        @copied_user = Factory(:user)
      end

      it "makes search setups belonging to a copied user available to the view" do
        
        ss_assigned_1 = Factory(:search_setup, name: 'bar', user: @copied_user)
        ss_assigned_2 = Factory(:search_setup, name: 'foo', user: @copied_user)
        3.times { Factory(:search_setup) }

        get :new, company_id: @copied_user.company.id, copy: @copied_user.id

        expect(assigns(:assigned_search_setups)).to be_empty
        expect(assigns(:available_search_setups)).to eq [ss_assigned_1, ss_assigned_2].sort{|ss1, ss2| ss1.name <=> ss2.name }
        
      end

      it "makes custom reports belonging to a copied user available to the view" do

        cr_assigned_1 = Factory(:custom_report, name: 'bar', user: @copied_user)
        cr_assigned_2 = Factory(:custom_report, name: 'foo', user: @copied_user)
        3.times { Factory(:custom_report) }

        get :new, company_id: @copied_user.company.id, copy: @copied_user.id

        expect(assigns(:assigned_custom_reports)).to be_empty 
        expect(assigns(:available_custom_reports)).to eq [cr_assigned_1, cr_assigned_2].sort{|cr1, cr2| cr1.name <=> cr2.name }
      end

      it "makes group memberships belonging to a copied user available to the view" do
        @copied_user.groups << gr_assigned_1 = Factory(:group)
        @copied_user.groups << gr_assigned_2 = Factory(:group)
        gr_available_1 = Factory(:group)
        gr_available_2 = Factory(:group)
        gr_available_3 = Factory(:group)

        get :new, company_id: @copied_user.company.id, copy: @copied_user.id

        expect(assigns(:assigned_groups)).to eq [gr_assigned_1, gr_assigned_2].sort{|gr1, gr2| gr1.name <=> gr2.name }
        expect(assigns(:available_groups)).to eq [gr_available_1, gr_available_2, gr_available_3].sort{ |gr1, gr2| gr1.name <=> gr2.name }
      end

      it "makes copied-user permissions available to view" do
        @copied_user.update_attributes(drawback_view: true)
        get :new, company_id: @copied_user.company.id, copy: @copied_user.id
        expect(assigns(:user).drawback_view).to be_truthy
      end
    end

    context "without authorization" do
      it "redirects" do
        copied_user = Factory(:user)
        get :new, company_id: copied_user.company.id, copy: copied_user.id
        expect(response).to be_redirect
      end
    end
  end

  describe "update" do
    before :each do
      @user.admin = true
      @user.save!
      @u = Factory(:user, password: "blah")
    end

    it "updates a user's info without password" do
      @u = Factory(:user, password: "blah")
      group = Factory(:group)
      # Verify the password doesn't change if we don't include it in the params
      pwd = @u.encrypted_password
      params = {company_id: @u.company.id, id: @u.id, user: {username: 'testing', group_ids: [group.id], password: "   ", password_confirmation: "  "}}

      post :update, params
      expect(response).to be_redirect

      @u.reload
      expect(@u.username).to eq 'testing'
      expect(@u.groups).to eq [group]
      expect(@u.encrypted_password).to eq pwd
    end

    it "updates a user's password" do
      @u = Factory(:user, password: "blah")
      group = Factory(:group)
      # Verify the password doesn't change if we don't include it in the params
      pwd = @u.encrypted_password
      params = {company_id: @u.company.id, id: @u.id, user: {username: 'testing', password: "testing", password_confirmation: "testing"}}

      post :update, params
      expect(response).to be_redirect

      @u.reload
      expect(@u.username).to eq 'testing'
      expect(@u.encrypted_password).not_to eq pwd
      expect(User.authenticate 'testing', 'testing').to be_truthy
    end
  end
  describe "event_subscriptions" do
    it "should work with user id" do
      u = Factory(:user)
      expect_any_instance_of(User).to receive(:can_edit?).and_return true
      get :event_subscriptions, id: u.id, company_id: u.company_id
      expect(assigns(:user)).to eq u
      expect(response).to be_success
    end
    it "should work without user id" do
      u = Factory(:user)
      get :event_subscriptions
      expect(assigns(:user)).to eq @user
      expect(response).to be_success
    end
  end
  describe 'hide_message' do
    it "should hide message" do
      post :hide_message, :message_name=>'mn'
      @user.reload
      expect(@user.hide_message?('mn')).to be_truthy
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({'OK'=>'OK'})
    end
  end
  describe 'show_bulk_upload' do
    it "should show bulk upload for admin" do
      @user.admin = true
      @user.save!
      get :show_bulk_upload, 'company_id'=>@user.company_id.to_s
      expect(response).to be_success
    end
    it "should not show bulk upload for non-admin" do
      get :show_bulk_upload, 'company_id'=>@user.company_id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
  end
  describe 'bulk_upload' do
    it "should create users from csv" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,fred@sample.com,Fred,Dryer,fd654321"
      post :bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data, 'user'=>{'order_view'=>1,'email_format'=>'html'}
      expect(response).to be_success
      expect(JSON.parse(response.body)['count']).to eq(2)
      u = User.find_by_company_id_and_username @user.company_id, 'uname'
      expect(u.email).to eq('joe@sample.com')
      expect(u.first_name).to eq('Joe')
      expect(u.last_name).to eq('Smith')
      expect(u).to be_order_view
      expect(u).not_to be_order_edit
      expect(u.email_format).to eq('html')
      expect(u.encrypted_password).to_not be_nil

      u = User.find_by_company_id_and_username @user.company_id, 'un2'
      expect(u.email).to eq('fred@sample.com')
      expect(u.first_name).to eq('Fred')
      expect(u.last_name).to eq('Dryer')
      expect(u).to be_order_view
      expect(u).not_to be_order_edit
      expect(u.email_format).to eq('html')

    end
    it "should show errors for some users while creating others" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)
      data = "uname,joe@sample.com,Joe,Smith,js1234567\n,f,Fred,Dryer,fd654321"
      post :bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data, 'user'=>{'order_view'=>1,'email_format'=>'html'}
      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)['error']).not_to be_blank
    end
    it "should fail if user not admin" do
      allow_any_instance_of(User).to receive(:admin?).and_return(false)
      uc = User.all.size
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,fred@sample.com,Fred,Dryer,fd654321"
      post :bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data, 'user'=>{'order_view'=>1,'email_format'=>'html'}
      expect(response).to be_redirect
      expect(User.all.size).to eq(uc)
    end
  end
  describe 'preview_bulk_upload' do
    it "should return json table" do
      data = "uname,joe@sample.com,Joe,Smith,js1234567\nun2,fred@sample.com,Fred,Dryer,fd654321"
      post :preview_bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data
      expect(response).to be_success
      h = JSON.parse response.body
      expect(h['results'].size).to eq(2)
      r = h['results']
      expect(r[0]).to eq({'username'=>'uname','email'=>'joe@sample.com','first_name'=>'Joe','last_name'=>'Smith','password'=>'js1234567'})
      expect(r[1]).to eq({'username'=>'un2','email'=>'fred@sample.com','first_name'=>'Fred','last_name'=>'Dryer','password'=>'fd654321'})
    end
    it "should return 400 with error if not valid csv" do
      data = "uname,\""
      post :preview_bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data
      expect(response.status).to eq(400)
    end
    it "should return 400 with error if not right number of elements" do
      data = "uname"
      post :preview_bulk_upload, 'company_id'=>@user.company_id.to_s, 'bulk_user_csv'=>data
      expect(response.status).to eq(400)
    end
  end

  describe "bulk_invite" do

    it "should invite multiple users" do
      @user.admin = true
      @user.save

      expect(User).to receive(:delay).and_return User
      expect(User).to receive(:send_invite_emails).with ["1", "2", "3"]
      post :bulk_invite, id: [1, 2, 3], company_id: @user.company_id

      expect(response).to redirect_to company_users_path @user.company_id
      expect(flash[:notices].first).to eq("The user invite emails will be sent out shortly.")
    end

    it "should only allow admins access" do
      @user.admin = false
      @user.save

      post :bulk_invite, id: [1, 2, 3], company_id: @user.company_id

      expect(response).to redirect_to "/"
      expect(flash[:errors].first).to eq("Only administrators can send invites to users.")
    end

    it "should verify at least one user selected" do
      @user.admin = true
      @user.save

      post :bulk_invite, company_id: @user.company_id
      expect(response).to redirect_to company_users_path @user.company_id
      expect(flash[:errors].first).to eq("Please select at least one user.")
    end
  end

  describe "set_homepage" do
    it "sets the users homepage" do
      post :set_homepage, homepage: "http://www.test.com/homepage/index.html?param1=1&param2=2#hash=123"
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({'OK'=>'OK'})

      @user.reload
      expect(@user.homepage).to eq "/homepage/index.html?param1=1&param2=2#hash=123"
    end

    it "sets unsets the users homepage" do
      @user.update_attributes! homepage: "/index.html"
      post :set_homepage, homepage: ""
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({'OK'=>'OK'})

      @user.reload
      expect(@user.homepage).to eq ""
    end

    it "returns an error when no homepage param is present" do
      post :set_homepage
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({'error' => "Homepage URL missing."})
    end
  end

  describe "move_to_new_company" do
    
    before :each do
      @user1 = Factory(:user)
      @user2 = Factory(:user)
      @user3 = Factory(:user)
      @company = Factory(:company)
      # So the :back redirect in the controller returns something
      request.env["HTTP_REFERER"] = "/referer"
    end

    it "should only allow admins access" do
      @user.admin = false
      @user.save

      post :move_to_new_company, id: [@user1.id, @user2.id, @user3.id], destination_company_id: @company.id

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("Only administrators can move other users to a new company.")
    end

    it "should move users to the correct company" do
      @user.admin = true
      @user.save

      post :move_to_new_company, id: [@user1.id, @user2.id, @user3.id], destination_company_id: @company.id

      expect(response).to redirect_to "/referer"

      @user1.reload; expect(@user1.company.id).to eq(@company.id)
      @user2.reload; expect(@user2.company.id).to eq(@company.id)
      @user3.reload; expect(@user3.company.id).to eq(@company.id)
    end

  end

  describe "unlock_user" do
    before :each do
      # So the :back redirect in the controller returns something
      request.env["HTTP_REFERER"] = "/referer"
    end

    it "should error when the user is not found" do
      @user.admin = true
      @user.save

      post :unlock_user, username: "AugustusGloop"
      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("User with username AugustusGloop not found.")
    end

    it "should error when the current user is not an admin" do
      @user.admin = false
      @user.save

      company = Factory.create(:company)
      locked_user = Factory(:user, username: "AugustusGloop", password_locked: true, company: company)

      post :unlock_user, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("You must be an administrator to unlock a user.")
    end

    it "should unlock the user when the current user is an admin" do
      @user.admin = true
      @user.save

      company = Factory.create(:company)
      locked_user = Factory(:user, username: "AugustusGloop", password_locked: true, company: company)

      post :unlock_user, username: "AugustusGloop"

      expect(response).to redirect_to(edit_company_user_path(locked_user.company, locked_user))
      expect(flash[:notices]).to include("User with username #{locked_user.username} unlocked.")
      locked_user.reload
      expect(locked_user.password_locked).to eq(false)
    end
  end

  describe "enable_run_as" do
    before :each do
      # So the :back redirect in the controller returns something
      request.env["HTTP_REFERER"] = "/referer"
    end

    it "should enable run as functionality for a non-disabled user when current user is an admin" do
      @user.admin = true
      @user.save

      run_as_user = Factory(:user, username: "AugustusGloop", disabled: false, password_locked: false, password_expired: false, password_reset: false)

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/"
      expect(flash[:errors]).to be_nil
      expect(@user.run_as).to eq(run_as_user)
    end

    it "should error when the current user is not an admin" do
      @user.admin = false
      @user.save

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("You must be an administrator to run as a different user.")
      expect(@user.run_as).to be_nil
    end

    it "should error when the run as user is not found" do
      @user.admin = true
      @user.save

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("User with username AugustusGloop not found.")
      expect(@user.run_as).to be_nil
    end

    it "should error when run as user has been disabled" do
      @user.admin = true
      @user.save

      run_as_user = Factory(:user, username: "AugustusGloop", disabled: true, password_locked: false, password_expired: false, password_reset: false)

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("This username is locked and not available for use with this feature.  Select another username or have this user account unlocked.")
      expect(@user.run_as).to be_nil
    end

    it "should error when run as user's password has been locked" do
      @user.admin = true
      @user.save

      run_as_user = Factory(:user, username: "AugustusGloop", disabled: false, password_locked: true, password_expired: false, password_reset: false)

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("This username is locked and not available for use with this feature.  Select another username or have this user account unlocked.")
      expect(@user.run_as).to be_nil
    end

    it "should error when run as user's password has expired" do
      @user.admin = true
      @user.save

      run_as_user = Factory(:user, username: "AugustusGloop", disabled: false, password_locked: false, password_expired: true, password_reset: false)

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("This username is locked and not available for use with this feature.  Select another username or have this user account unlocked.")
      expect(@user.run_as).to be_nil
    end

    it "should error when run as user's password is in reset status" do
      @user.admin = true
      @user.save

      run_as_user = Factory(:user, username: "AugustusGloop", disabled: false, password_locked: false, password_expired: false, password_reset: true)

      post :enable_run_as, username: "AugustusGloop"

      expect(response).to redirect_to "/referer"
      expect(flash[:errors].first).to eq("This username is locked and not available for use with this feature.  Select another username or have this user account unlocked.")
      expect(@user.run_as).to be_nil
    end
  end

end