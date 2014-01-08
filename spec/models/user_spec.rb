require 'spec_helper'

describe User do
  describe :magic_columns do
    before :each do
      @updated_at = 1.year.ago
      @u = Factory(:user,:updated_at=>@updated_at)
    end
    it "should not update updated_at if only authlogic columns changed" do
      @u.perishable_token='12345'
      @u.save!
      User.find(@u.id).updated_at.to_i.should == @updated_at.to_i
      User.record_timestamps.should be_true
    end
    it "should update updated_at if non-authlogic column changes" do
      @u.update_attributes(:email=>'a@sample.com')
      User.record_timestamps.should be_true
      User.find(@u.id).updated_at.should > 10.seconds.ago
    end
    it "should update updated_at if both non-authlogic and authlogic columns change" do
      @u.update_attributes(:perishable_token=>'12345',:email=>'a@sample.com')
      User.record_timestamps.should be_true
      User.find(@u.id).updated_at.should > 10.seconds.ago
    end
  end
  context "permissions" do
    context "official tariffs" do
      it "should allow master company user" do
        Factory(:master_user).should be_view_official_tariffs
      end
      it "should not allow non master company user" do
        Factory(:user).should_not be_view_official_tariffs
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
        # Make sure the password was updated and user was set to force
        # reset password
        user.crypted_password.should_not == u.crypted_password
        user.password_reset.should be_true
        user.perishable_token.should_not == u.perishable_token

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
  describe :reset_password_prep do
    it "should update updated_at and change the perishable token" do
      @u = Factory(:user)

      updated = @u.updated_at
      token = @u.perishable_token
      sleep 0.5

      @u.reset_password_prep
      @u.perishable_token.should_not == updated
      @u.perishable_token.should_not == token
    end
  end
end
