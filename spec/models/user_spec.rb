require 'spec_helper'

describe User do
  context "permissions" do
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
end
