require 'spec_helper'

describe User do
  describe :groups do
    before :each do
      @gA = Factory(:group,system_code:'groupA')

      @u1 = Factory(:user)
      @gA.users << @u1
      @u1.reload

      @gB = Factory(:group,system_code:'groupB')
    end
    it "should find in_group?" do
      expect(@u1.in_group?('groupA')).to be_true
      expect(@u1.in_group?(@gA)).to be_true
      expect(@u1.in_group?('groupB')).to be_false
      expect(@u1.in_group?(@gB)).to be_false
    end
    it "should find in_any_group?" do
      expect(@u1.in_any_group?(['groupA','groupB'])).to be_true
      expect(@u1.in_any_group?([@gA,@gB])).to be_true
      expect(@u1.in_any_group?(['groupB'])).to be_false
      expect(@u1.in_any_group?([@gB])).to be_false
    end
  end
  describe :available_importers do
    before :each do
      @c1 = Factory(:company,importer:true)
      @c2 = Factory(:company,importer:true)
      @c3 = Factory(:company,importer:true)
      @c4 = Factory(:company) #not an importer
    end
    it "should show all importers if master company" do
      u = Factory(:master_user)
      expect(u.available_importers.to_a).to eq [@c1,@c2,@c3]
    end
    it "should show all linked importers" do
      u = Factory(:user,company:@c4)
      @c4.linked_companies << @c1
      expect(u.available_importers.to_a).to eq [@c1]
    end
    it "should show me if i'm an importer" do
      u = Factory(:user,company:@c2)
      @c2.linked_companies << @c1
      expect(u.available_importers.to_a).to eq [@c1,@c2]
    end
  end
  describe :api_admin do
    it "should create api_admin if it doesn't exist" do
      u = User.api_admin
      expect(u.username).to eq 'ApiAdmin'
      expect(u.first_name).to eq 'API'
      expect(u.last_name).to eq 'Admin'
      expect(u.email).to eq 'bug+api_admin@vandegriftinc.com'
      expect(u.company).to be_master
      expect(u).to be_admin
      expect(u.api_auth_token).to_not be_blank
      expect(u.time_zone).to eq "Eastern Time (US & Canada)"
      expect(u.disallow_password).to be_true
    end
    it "should return api_admin if it exits" do
      u = Factory(:master_user,username:'ApiAdmin')
      expect(User.api_admin).to eq u
    end
  end
  describe :integration do
    it "should create integration if it doesn't exist" do
      u = User.integration
      expect(u.username).to eq 'integration'
      expect(u.first_name).to eq 'Integration'
      expect(u.last_name).to eq 'User'
      expect(u.email).to eq 'bug+integration@vandegriftinc.com'
      expect(u.company).to be_master
      expect(u).to be_admin
      expect(u.api_auth_token).to_not be_blank
      expect(u.time_zone).to eq "Eastern Time (US & Canada)"
      expect(u.disallow_password).to be_true
    end
    it "should return integration if it exits" do
      u = Factory(:master_user,username:'integration')
      expect(User.integration).to eq u
    end
  end
  describe :magic_columns do
    before :each do
      @updated_at = 1.year.ago
      @u = Factory(:user,:updated_at=>@updated_at)
    end
    it "should not update updated_at if only confirmation token changed" do
      @u.confirmation_token='12345'
      @u.save!
      User.find(@u.id).updated_at.to_i.should == @updated_at.to_i
      User.record_timestamps.should be_true
    end
    it "should not update updated_at if only remember token changed" do
      @u.remember_token='12345'
      @u.save!
      User.find(@u.id).updated_at.to_i.should == @updated_at.to_i
      User.record_timestamps.should be_true
    end
    it "should not update updated_at if only last request at changed" do
      @u.last_request_at = Time.zone.now
      @u.save!
      User.find(@u.id).updated_at.to_i.should == @updated_at.to_i
      User.record_timestamps.should be_true
    end
    it "should not update updated_at if all no-update fields changed" do
      @u.confirmation_token='12345'
      @u.remember_token='12345'
      @u.last_request_at = Time.zone.now
      @u.save!
      User.find(@u.id).updated_at.to_i.should == @updated_at.to_i
      User.record_timestamps.should be_true
    end
    it "should update updated_at if a standard column changes" do
      @u.update_attributes(:email=>'a@sample.com')
      User.record_timestamps.should be_true
      User.find(@u.id).updated_at.should > 10.seconds.ago
    end
    it "should update updated_at if both standard and no-update columns change" do
      @u.update_attributes(:perishable_token=>'12345',:email=>'a@sample.com')
      User.record_timestamps.should be_true
      User.find(@u.id).updated_at.should > 10.seconds.ago
    end
  end
  context "permissions" do
    context "vendors" do
      before :each do
        MasterSetup.any_instance.stub(:vendor_management_enabled?).and_return true
      end
      it "should allow when MasterSetup.vendor_management_enabled? and I have vendor_X permission" do
        expect(User.new(vendor_view:true).view_vendors?).to be_true
        expect(User.new(vendor_edit:true).edit_vendors?).to be_true
        expect(User.new(vendor_attach:true).attach_vendors?).to be_true
        expect(User.new(vendor_comment:true).comment_vendors?).to be_true
      end
      it "should not allow when !MasterSetup.vendor_management_enabled?" do
        MasterSetup.any_instance.stub(:vendor_management_enabled?).and_return false
        expect(User.new(vendor_view:true).view_vendors?).to be_false
        expect(User.new(vendor_edit:true).edit_vendors?).to be_false
        expect(User.new(vendor_attach:true).attach_vendors?).to be_false
        expect(User.new(vendor_comment:true).comment_vendors?).to be_false
      end
      it "should not allow when I dont have vendor_view permission" do
        expect(User.new.view_vendors?).to be_false
        expect(User.new.edit_vendors?).to be_false
        expect(User.new.attach_vendors?).to be_false
        expect(User.new.comment_vendors?).to be_false
      end
    end
    context "official tariffs" do
      it "should allow master company user" do
        Factory(:master_user).should be_view_official_tariffs
      end
      it "should not allow non master company user" do
        Factory(:user).should_not be_view_official_tariffs
      end
    end
    context "business_validation_results" do
      it "should allow master users" do
        u = Factory(:master_user)
        expect(u.view_business_validation_results?).to be_true
        expect(u.edit_business_validation_results?).to be_true
      end
      it "should not allow non-master users" do
        u = Factory(:importer_user)
        expect(u.view_business_validation_results?).to be_false
        expect(u.edit_business_validation_results?).to be_false
      end
      it "allows importer user if company has business rules viewing allowed" do
        u = Factory(:importer_user)
        u.company.update_attributes! show_business_rules: true

        expect(u.view_business_validation_results?).to be_true
        expect(u.edit_business_validation_results?).to be_true
      end
    end
    context "business_validation_rule_results" do
      it "should allow master users" do
        u = Factory(:master_user)
        expect(u.view_business_validation_rule_results?).to be_true
        expect(u.edit_business_validation_rule_results?).to be_true
      end
      it "shouldn't allow non master users" do
        u = Factory(:importer_user)
        expect(u.view_business_validation_rule_results?).to be_false
        expect(u.edit_business_validation_rule_results?).to be_false
      end
      it "allows importer user if company has business rules viewing allowed" do
        u = Factory(:importer_user)
        u.company.update_attributes! show_business_rules: true

        expect(u.view_business_validation_rule_results?).to be_true
        expect(u.edit_business_validation_rule_results?).to be_true
      end
    end
    context "projects" do
      it "should allow master company user with permission" do
        u = Factory(:master_user)
        expect(u.view_projects?).to be_false
        expect(u.edit_projects?).to be_false
        u.project_view = true
        expect(u.view_projects?).to be_true
        u.project_edit = true
        expect(u.edit_projects?).to be_true
      end
      it "should not allow non master company user" do
        u = Factory(:user)
        u.project_view = true
        u.project_edit = true
        expect(u.view_projects?).to be_false
        expect(u.edit_projects?).to be_false
      end
    end
    context "attachment_archives" do
      it "should allow for master user who can view entries" do
        u = Factory(:user,:company=>Factory(:company,:master=>true))
        u.stub(:view_entries?).and_return true
        u.should be_view_attachment_archives
        u.should be_edit_attachment_archives
      end
      it "should not allow for non-master user" do
        u = Factory(:user)
        u.stub(:view_entries?).and_return true
        u.should_not be_view_attachment_archives
        u.should_not be_edit_attachment_archives
      end
      it "should not allow for user who cannot view entries" do
        u = Factory(:user,:company=>Factory(:company,:master=>true))
        u.stub(:view_entries?).and_return false
        u.should_not be_view_attachment_archives
        u.should_not be_edit_attachment_archives
      end
    end
    context "security filing" do
      context "company has permission" do
        before :each do
          Company.any_instance.stub(:view_security_filings?).and_return(true)
          Company.any_instance.stub(:edit_security_filings?).and_return(true)
          Company.any_instance.stub(:attach_security_filings?).and_return(true)
          Company.any_instance.stub(:comment_security_filings?).and_return(true)
        end
        it "should allow if permission set and company has permission" do
          u = Factory(:user,:security_filing_view=>true,:security_filing_edit=>true,:security_filing_attach=>true,:security_filing_comment=>true)
          u.view_security_filings?.should be_true
          u.edit_security_filings?.should be_true
          u.attach_security_filings?.should be_true
          u.comment_security_filings?.should be_true
        end
        it "should not allow if user permission not set and company has permission" do
          u = Factory(:user,:security_filing_view=>false,:security_filing_edit=>false,:security_filing_attach=>false,:security_filing_comment=>false)
          u.view_security_filings?.should be_false
          u.edit_security_filings?.should be_false
          u.attach_security_filings?.should be_false
          u.comment_security_filings?.should be_false
        end
      end
      it "should not allow if company does not have permission" do
        Company.any_instance.stub(:view_security_filings?).and_return(false)
        Company.any_instance.stub(:edit_security_filings?).and_return(false)
        Company.any_instance.stub(:attach_security_filings?).and_return(false)
        Company.any_instance.stub(:comment_security_filings?).and_return(false)
        u = Factory(:user,:security_filing_view=>true,:security_filing_edit=>true,:security_filing_attach=>true,:security_filing_comment=>true)
        u.view_security_filings?.should be_false
        u.edit_security_filings?.should be_false
        u.attach_security_filings?.should be_false
        u.comment_security_filings?.should be_false
      end
    end
    context "drawback" do
      before :each do
        MasterSetup.get.update_attributes(:drawback_enabled=>true)
      end
      it "should allow user to view if permission is set and drawback enabled" do
        Factory(:user,:drawback_view=>true).view_drawback?.should be_true
      end
      it "should allow user to edit if permission is set and drawback enabled" do
        Factory(:user,:drawback_edit=>true).edit_drawback?.should be_true
      end
      it "should not allow view/edit if drawback not enabled" do
        MasterSetup.get.update_attributes(:drawback_enabled=>false)
        u = Factory(:user,:drawback_view=>true,:drawback_edit=>true)
        u.view_drawback?.should be_false
        u.edit_drawback?.should be_false
      end
      it "should now allow if permissions not set" do
        u = Factory(:user)
        u.view_drawback?.should be_false
        u.edit_drawback?.should be_false
      end
      it "should delegate to #view_drawback? when #comment_drawback? is called" do
        u = Factory(:user)
        u.should_receive :view_drawback?
        u.comment_drawback?
      end
    end
    context "broker invoice" do
      context "with company permission" do
        before :each do
          Company.any_instance.stub(:edit_broker_invoices?).and_return(true)
          Company.any_instance.stub(:view_broker_invoices?).and_return(true)
        end
        it "should allow view if permission is set" do
          Factory(:user,:broker_invoice_view=>true).view_broker_invoices?.should be_true
        end
        it "should allow edit if permission is set" do
          Factory(:user,:broker_invoice_edit=>true).edit_broker_invoices?.should be_true
        end
        it "should not allow view without permission" do
          Factory(:user,:broker_invoice_view=>false).view_broker_invoices?.should be_false
        end
        it "should not allow edit without permission" do
          Factory(:user,:broker_invoice_edit=>false).edit_broker_invoices?.should be_false
        end
      end
      context "without company permission" do
        before :each do
          Company.any_instance.stub(:edit_broker_invoices?).and_return(false)
          Company.any_instance.stub(:view_broker_invoices?).and_return(false)
        end
        it "should not allow view even if permission is set" do
          Factory(:user,:broker_invoice_view=>true).view_broker_invoices?.should be_false
        end
        it "should not allow edit even if permission is set" do
          Factory(:user,:broker_invoice_edit=>true).edit_broker_invoices?.should be_false
        end
      end
    end
    context "survey" do
      it "should pass view_surveys?" do
        User.new(:survey_view=>true).view_surveys?.should be_true
      end
      it "should pass edit_surveys?" do
        User.new(:survey_edit=>true).edit_surveys?.should be_true
      end
      it "should fail view_surveys?" do
        User.new(:survey_view=>false).view_surveys?.should be_false
      end
      it "should fail edit_surveys?" do
        User.new(:survey_edit=>false).edit_surveys?.should be_false
      end
    end
    context "entry" do
      before :each do
        @company = Factory(:company,:broker=>true)
      end
      it "should allow user to edit entry if permission is set and company is not broker" do
        Factory(:user,:entry_edit=>true,:company=>@company).should be_edit_entries
      end
      it "should not allow user to edit entry if permission is not set" do
        User.new(:company=>@company).should_not be_edit_entries
      end
      it "should not allow user to edit entry if company is not broker" do
        @company.update_attributes(:broker=>false)
        User.new(:entry_edit=>true,:company_id=>@company.id).should_not be_edit_entries
      end
    end

    context "commercial invoice" do
      context "entry enabled" do
        before :each do
          MasterSetup.get.update_attributes(:entry_enabled=>true)
        end
        it "should pass with user enabled" do
          User.new(:commercial_invoice_view=>true).view_commercial_invoices?.should be_true
          User.new(:commercial_invoice_edit=>true).edit_commercial_invoices?.should be_true
        end
        it "should fail with user not enabled" do
          User.new.view_commercial_invoices?.should be_false
          User.new.edit_commercial_invoices?.should be_false
        end
      end
      context "entry disabled" do
        before :each do
          MasterSetup.get.update_attributes(:entry_enabled=>false)
        end
        it "should fail with user enabled" do
          User.new(:commercial_invoice_view=>true).view_commercial_invoices?.should be_false
          User.new(:commercial_invoice_edit=>true).edit_commercial_invoices?.should be_false
        end
      end
    end
  end

  context :run_with_user_settings do

    before :each do
      @user = User.current
      @time = Time.zone

      @run_as = User.new :name => 'Run As', :time_zone => "Hawaii"
      @current_user = User.new :name => 'Current', :time_zone => "UTC"
      User.current = @current_user
      Time.zone = @current_user.time_zone
    end

    after :each do
      User.current = @user
      Time.zone = @time
    end

    it "should set/unset User settings" do

      val = User.run_with_user_settings(@run_as) do
        User.current.should == @run_as
        Time.zone.should == ActiveSupport::TimeZone[@run_as.time_zone]
        "abcdefg"
      end
      # Just make sure the method returns whatever the block returns
      val.should == "abcdefg"

      User.current.should == @current_user
      Time.zone.should == ActiveSupport::TimeZone[@current_user.time_zone]
    end

    it "should set/unset User settings even if block raises an Exception" do
      # Exception is used here since it's the base for any other errors (even syntax or "severe" runtime issues)
      expect {
        User.run_with_user_settings(@run_as) {
          raise Exception, "Error"
        }
      }.to raise_exception "Error"

      User.current.should == @current_user
      Time.zone.should == ActiveSupport::TimeZone[@current_user.time_zone]
    end

    it "should not set Time.zone if user has no timezone" do
      # the main admin user doesn't appear to have timezone set. User.run_with.. handles this
      # scenario just in case.
      @run_as.time_zone = ""

      User.run_with_user_settings(@run_as) do
        User.current.should == @run_as
        Time.zone.should == ActiveSupport::TimeZone[@current_user.time_zone]
      end

      User.current.should == @current_user
      Time.zone.should == ActiveSupport::TimeZone[@current_user.time_zone]
    end
  end
  describe 'hidden messages' do
    it "should add hidden message" do
      u = User.new
      u.add_hidden_message 'h1'
      u.hide_message?('h1').should be_true
    end
    it "should remove hidden message" do
      u = User.new
      u.add_hidden_message 'hx'
      u.remove_hidden_message 'hx'
      u.hide_message?('hx').should be_false
    end
    it "should save hidden messages" do
      u = Factory(:user)
      u.add_hidden_message 'hx'
      u.add_hidden_message 'abc'
      u.save!
      u = User.find(u.id)
      u.hide_message?('hx').should be_true
      u.hide_message?('abc').should be_true
    end
    it "should be case insensitive" do
      u = User.new
      u.add_hidden_message 'hx'
      u.hide_message?('HX').should be_true
    end
  end
  context :send_invite_emails do
    it "should send an invite email to a user" do
      e = double("Email")
      e.should_receive(:deliver)
      u = Factory(:user)

      OpenMailer.should_receive(:send_invite) do |user, password|
        user.id.should == u.id
        # Make sure the password has been updated by checking the encrypted
        # versions
        user.encrypted_password.should_not == u.encrypted_password
        expect(user.password_reset).to be_true
        e
      end

      User.send_invite_emails u.id
    end

    it "should send an invite email to multiple users" do
      e = double("email")
      e.should_receive(:deliver).twice
      OpenMailer.should_receive(:send_invite).twice.and_return(e)

      u = Factory(:user)
      User.send_invite_emails [u.id, u.id]
    end
  end

  describe "authenticate" do
    before :each do
      @user = Factory :user, password: "abc"
    end

    it "validates user exists with specified password" do
      expect(User.authenticate @user.username, "abc").to eq @user
    end

    it "returns nil if user is not found" do
      expect(User.authenticate "notauser", "abc").to be_nil
    end

    it "returns nil if user password is incorrect" do
      expect(User.authenticate @user.username, "notmypassword").to be_nil
    end

    it "returns nil if user can't use password login" do
      @user.update_attributes(disallow_password:true)
      expect(User.authenticate @user.username, "abc").to be_nil
    end
  end

  describe "access_allowed?" do
    it "validates user is not nill" do
      expect(User.access_allowed? nil).to be_false
    end

    it "validates user is not disabled?" do
      user = User.new
      user.disabled = true
      expect(User.access_allowed? user).to be_false
    end

    it "validates user company is not locked" do
      user = Factory(:user, company: Factory(:company, locked: true))
      expect(User.access_allowed? user).to be_false
    end

    it "validates user" do
      user = Factory(:user)
      expect(User.access_allowed? user).to be_true
    end
  end

  describe "update_user_password" do
    before :each do
      @user = Factory(:user)
    end

    it "updates a user password with valid info" do
      # Update the password and then validate that our authenticate method confirms
      # the password now matches the hash that our new password generates
      @user.update_user_password 'newpassword', 'newpassword'
      expect(User.authenticate @user.username, 'newpassword').to eq @user
    end

    it "validates password confirmation matches password" do
      @user.update_user_password 'newpassword', 'notmatched'
      expect(@user.errors.full_messages).to eq ["Password must match password confirmation."]
    end

    it "skips update if password is blank" do
      expect(@user.update_user_password ' ', 'notmatched').to be_true
      expect(User.authenticate @user.username, ' ').to be_nil
    end
  end

  describe "on_successful_login" do
    it "sets last_login_at, current_login_at, failed_login_count and creates a history record" do
      user = Factory(:user, current_login_at: Date.new(2014,1,1), failed_login_count: 10)
      last_login = user.current_login_at
      updated_at = user.updated_at

      request = double("request")
      request.stub(:host_with_port).and_return "localhost:3000"

      user.on_successful_login request

      user.reload
      expect(user.last_login_at).to eq last_login
      expect(user.current_login_at).to be >= 5.seconds.ago
      expect(user.failed_login_count).to eq 0
      expect(user.host_with_port).to eq "localhost:3000"
      # Don't want the login to update the user timestamps
      expect(user.updated_at.to_i).to eq updated_at.to_i
      expect(user.histories.where(history_type: 'login', company_id: user.company.id).first).to_not be_nil

    end

    it "doesn't update host with port if it's not blank" do
      user = Factory(:user, host_with_port: "www.test.com")
      user.on_successful_login double("request")

      user.reload
      expect(user.host_with_port).to eq "www.test.com"
    end
  end

  describe "from_omniauth" do
    before :each do
      @user = Factory(:user, email: "condaleeza@rice.com")
    end

    context "google oauth" do
      it "should return an updated user when a user is found" do
        info = OpenStruct.new({"email" => "condaleeza@rice.com", "name" => "Condaleeza R"})
        creds = OpenStruct.new({"token" => "123456789", "expires_at" => (Time.now + 5.days).to_i})
        auth = OpenStruct.new({"info" => info, "provider" => "oauth", "uid" => "someuid123", "credentials" => creds})

        expect(User.from_omniauth("google_oauth2", auth)).to eq ({user: @user, errors: []})

        @user.reload
        @user.provider.should == "oauth"
        @user.uid.should == "someuid123"
        @user.google_name.should == "Condaleeza R"
        @user.oauth_token.should == "123456789"
        (@user.oauth_expires_at > Time.now).should == true
      end

      it "should return nil if the user is not found" do
        info = OpenStruct.new({"email" => "susan@rice.com", "name" => "Condaleeza R"})
        creds = OpenStruct.new({"token" => "123456789", "expires_at" => (Time.now + 5.days).to_i})
        auth = OpenStruct.new({"info" => info, "provider" => "google_oauth2", "uid" => "someuid123", "credentials" => creds})

        expect(User.from_omniauth("google_oauth2", auth)).to eq ({user: nil, errors: ["Google email account susan@rice.com has not been set up in VFI Track."]})
      end
    end

    context "pepsi SAML" do
      it "finds user by uid from SAML response" do
        expect(User.from_omniauth("pepsi-saml", OpenStruct.new({"uid" => @user.username}))).to eq ({user: @user, errors: []})
      end

      it "returns an error if user is not found" do
        expect(User.from_omniauth("pepsi-saml", OpenStruct.new({"uid" => "notausername"}))).to eq ({user: nil, errors: ["Pepsi User ID notausername has not been set up in VFI Track."]})
      end
    end
  end

  describe "username uniqueness" do
    it "should prevent duplicate usernames without case sensitivity" do
      c = Factory(:company)
      u1 = User.new(email: "example@example.com", username: "username")
      u1.password = "password"
      u1.company = c
      u1.save!

      u2 = User.new(email: "example2@example.com", username: "username")
      u2.password = "password"
      u2.company = c
      expect{ u2.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Username has already been taken")

      u3 = User.new(email: "example2@example.com", username: "USERNAME")
      u3.password = "password"
      u3.company = c
      expect{ u3.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Username has already been taken")
    end
  end

  describe "email validation" do
    it "should update email field if all members of semicolon/comma-separated list match regex pattern" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      list = "abc@example.net, nbc123@vandegriftinc.com; cbs_1@britishcompany.co.uk"
      u.update_attributes(email: list)
      u.reload
      expect(u.email).to eq list
      expect(u.errors.messages[:email]).to be_nil
    end

    it "should not update email field if any member of semicolon/comma-separated list fails to match regex pattern" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      list = "abc@example.*et, nbc123grifter.com; 1@2.3.com, cbs@somewhere.org"
      u.update_attributes(email: list)
      u.reload
      expect(u.email).to eq "default@vandegriftinc.com"
      expect(u.errors.messages[:email]).to eq ["The following emails are invalid: abc@example.*et, nbc123grifter.com, 1@2.3.com"]
    end
  
    it "should have a different error for one invalid email" do
      u = Factory(:user, email: "default@vandegriftinc.com")
      addr = "abc@example.*et"
      u.update_attributes(email: addr)
      u.reload
      expect(u.email).to eq "default@vandegriftinc.com"
      expect(u.errors.messages[:email]).to eq ["Invalid email address"]
    end

  end
end
