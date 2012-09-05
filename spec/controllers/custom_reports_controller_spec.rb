require 'spec_helper'

describe CustomReportsController do
  before :each do
    @u = Factory(:master_user)
    CustomReportEntryInvoiceBreakdown.stub(:can_view?).and_return(true)
    activate_authlogic
    UserSession.create! @u
  end

  describe :run do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id,:name=>"ABCD")
    end
    it "should not run if report user does not match current_user" do
      ReportResult.should_not_receive(:run_report!)
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      get :run, :id=>@rpt.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should create report result" do
      CustomReportsController.any_instance.stub(:current_user).and_return(@u) #need actual object for should_receive call below
      ReportResult.should_receive(:run_report!).with(@rpt.name,@u,CustomReportEntryInvoiceBreakdown,{:friendly_settings=>["Report Template: #{CustomReportEntryInvoiceBreakdown.template_name}"],:custom_report_id=>@rpt.id})
      get :run, :id=>@rpt.id
      response.should be_redirect
      flash[:notices].first.should == "Your report has been scheduled. You'll receive a system message when it finishes."
    end
  end
  describe :new do
    it "should require a type parameter" do
      get :new
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should set the @report_obj value" do
      get :new, :type=>'CustomReportEntryInvoiceBreakdown'
      response.should be_success
      assigns[:report_obj].is_a?(CustomReportEntryInvoiceBreakdown).should == true
    end
    it "should error if the type is not a subclass of CustomReport" do
      get :new, :type=>'String'
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should error if user cannot view report" do
      CustomReportEntryInvoiceBreakdown.stub(:can_view?).and_return(false)
      get :new, :type=>'CustomReportEntryInvoiceBreakdown'
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end

  describe :show do
    it "should error if user doesn't match current_user" do
      rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>Factory(:user).id)
      get :show, :id=>rpt.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should set the report_obj variable" do
      rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
      get :show, :id=>rpt.id
      response.should be_success
      assigns(:report_obj).should == rpt
    end
  end

  describe :destroy do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
    end
    it "should not destroy if user_id doesn't match current user" do
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      delete :destroy, :id=>@rpt.id
      response.should be_redirect
      CustomReport.find_by_id(@rpt.id).should_not be_nil
    end
    it "should destroy report" do
      delete :destroy, :id=>@rpt.id
      response.should be_redirect
      CustomReport.find_by_id(@rpt.id).should be_nil
    end
  end

  describe :update do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
    end
    it "should update report" do
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      @rpt.reload
      @rpt.is_a?(CustomReportEntryInvoiceBreakdown).should be_true
      @rpt.should have(2).search_columns
      @rpt.should have(1).search_criterions
      @rpt.search_columns.collect {|sc| sc.model_field_uid}.should == ['bi_brok_ref','bi_entry_num']
      sp = @rpt.search_criterions.first
      sp.model_field_uid.should == 'bi_brok_ref'
      sp.operator.should == 'eq'
      sp.value.should == '123'
      response.should redirect_to custom_report_path(@rpt)
    end
    it "should not duplicate columns" do
      @rpt.search_columns.create!(:model_field_uid=>'bi_brok_ref')
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      @rpt.reload
      @rpt.is_a?(CustomReportEntryInvoiceBreakdown).should be_true
      @rpt.should have(2).search_columns
    end
    it "should error if user_id does not match current user" do
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      @rpt.reload
      @rpt.search_columns.should be_empty
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should strip fields user cannot view" do
      ModelField.find_by_uid(:bi_brok_ref).stub(:can_view?).and_return(false)
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      @rpt.reload
      @rpt.should have(1).search_columns
      @rpt.search_columns.first.model_field_uid.should == 'bi_entry_num'
    end
    it "should strip parameters user cannot view" do
      ModelField.find_by_uid(:bi_brok_ref).stub(:can_view?).and_return(false)
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      CustomReport.first.search_criterions.should be_empty
    end
  end

  describe :preview do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
    end
    it "should write error message text if user does not equal current user" do
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      get :preview, :id=>@rpt.id
      response.body.should == "You cannot preview another user's report."
    end
    it "should render result if user matches current user" do
      get :preview, :id=>@rpt.id
      response.should be_success
    end
  end
  describe :create do
    it "should create report of proper class" do
      post :create, {:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      rpt = CustomReport.first
      rpt.is_a?(CustomReportEntryInvoiceBreakdown).should be_true
      rpt.should have(2).search_columns
      rpt.should have(1).search_criterions
      rpt.search_columns.collect {|sc| sc.model_field_uid}.should == ['bi_brok_ref','bi_entry_num']
      sp = rpt.search_criterions.first
      sp.model_field_uid.should == 'bi_brok_ref'
      sp.operator.should == 'eq'
      sp.value.should == '123'
      response.should redirect_to custom_report_path(rpt)
    end
    it "should error if user cannot view report class" do
      CustomReportEntryInvoiceBreakdown.stub(:can_view?).and_return(false)
      post :create, {:custom_report=>{:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown'}}
      response.should be_redirect
      flash[:errors].first.should == "You do not have permission to use the #{CustomReportEntryInvoiceBreakdown.template_name} report."
    end
    it "should error if type is not a subclass of CustomReport" do
      post :create, {:custom_report=>{:name=>'ABC',:type=>'String'}}
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should error if type is not set" do
      post :create, {:custom_report=>{:name=>'ABC',:type=>''}}
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should strip fields user cannot view" do
      ModelField.find_by_uid(:bi_brok_ref).stub(:can_view?).and_return(false)
      post :create, {:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      rpt = CustomReport.first
      rpt.should have(1).search_columns
      rpt.search_columns.first.model_field_uid.should == 'bi_entry_num'
    end
    it "should strip parameters user cannot view" do
      ModelField.find_by_uid(:bi_brok_ref).stub(:can_view?).and_return(false)
      post :create, {:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      CustomReport.first.search_criterions.should be_empty
    end
    it "should inject current user's user_id" do
      post :create, {:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      CustomReport.first.user.should == @u
    end
  end
end
