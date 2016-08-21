require 'spec_helper'

describe CustomReportsController do
  before :each do
    @u = Factory(:master_user)
    allow(CustomReportEntryInvoiceBreakdown).to receive(:can_view?).and_return(true)

    sign_in_as @u
  end

  describe :run do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id,:name=>"ABCD")
    end
    it "should not run if report user does not match current_user" do
      expect(ReportResult).not_to receive(:run_report!)
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      get :run, :id=>@rpt.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should create report result" do
      allow_any_instance_of(CustomReportsController).to receive(:current_user).and_return(@u) #need actual object for should_receive call below
      expect(ReportResult).to receive(:run_report!).with(@rpt.name,@u,CustomReportEntryInvoiceBreakdown,{:friendly_settings=>["Report Template: #{CustomReportEntryInvoiceBreakdown.template_name}"],:custom_report_id=>@rpt.id})
      get :run, :id=>@rpt.id
      expect(response).to be_redirect
      expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
    end
  end
  describe :new do
    it "should require a type parameter" do
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should set the @report_obj value" do
      get :new, :type=>'CustomReportEntryInvoiceBreakdown'
      expect(response).to be_success
      expect(assigns(:report_obj).is_a?(CustomReport)).to eq(true)
      expect(assigns(:custom_report_type)).to eq('CustomReportEntryInvoiceBreakdown')
    end
    it "should error if the type is not a subclass of CustomReport" do
      get :new, :type=>'String'
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should error if user cannot view report" do
      allow(CustomReportEntryInvoiceBreakdown).to receive(:can_view?).and_return(false)
      get :new, :type=>'CustomReportEntryInvoiceBreakdown'
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe :show do
    it "should error if user doesn't match current_user" do
      rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>Factory(:user).id)
      get :show, :id=>rpt.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should set the report_obj variable" do
      rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
      get :show, :id=>rpt.id
      expect(response).to be_success
      expect(assigns(:report_obj)).to eq(rpt)
    end
  end

  describe :destroy do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
    end
    it "should not destroy if user_id doesn't match current user" do
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      delete :destroy, :id=>@rpt.id
      expect(response).to be_redirect
      expect(CustomReport.find_by_id(@rpt.id)).not_to be_nil
    end
    it "should destroy report" do
      delete :destroy, :id=>@rpt.id
      expect(response).to be_redirect
      expect(CustomReport.find_by_id(@rpt.id)).to be_nil
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
      expect(@rpt.is_a?(CustomReportEntryInvoiceBreakdown)).to be_truthy
      expect(@rpt.search_columns.size).to eq(2)
      expect(@rpt.search_criterions.size).to eq(1)
      expect(@rpt.search_columns.collect {|sc| sc.model_field_uid}).to eq(['bi_brok_ref','bi_entry_num'])
      sp = @rpt.search_criterions.first
      expect(sp.model_field_uid).to eq('bi_brok_ref')
      expect(sp.operator).to eq('eq')
      expect(sp.value).to eq('123')
      expect(response).to redirect_to custom_report_path(@rpt)
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
      expect(@rpt.is_a?(CustomReportEntryInvoiceBreakdown)).to be_truthy
      expect(@rpt.search_columns.size).to eq(2)
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
      expect(@rpt.search_columns).to be_empty
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should strip fields user cannot view" do
      allow(ModelField.find_by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      @rpt.reload
      expect(@rpt.search_columns.size).to eq(1)
      expect(@rpt.search_columns.first.model_field_uid).to eq('bi_entry_num')
    end
    it "should strip parameters user cannot view" do
      allow(ModelField.find_by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      put :update, {:id=>@rpt.id,:custom_report=>
        {:name=>'ABC',:type=>'CustomReportEntryInvoiceBreakdown',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      expect(CustomReport.first.search_criterions).to be_empty
    end
  end

  describe :preview do
    before :each do
      @rpt = CustomReportEntryInvoiceBreakdown.create!(:user_id=>@u.id)
    end
    it "should write error message text if user does not equal current user" do
      @rpt.update_attributes(:user_id=>Factory(:user).id)
      get :preview, :id=>@rpt.id
      expect(response.body).to eq("You cannot preview another user's report.")
    end
    it "should render result if user matches current user" do
      get :preview, :id=>@rpt.id
      expect(response).to be_success
    end
  end
  describe :create do
    it "should create report of proper class" do
      post :create, {:custom_report_type=>'CustomReportEntryInvoiceBreakdown',:custom_report=>
        {:name=>'ABC',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      rpt = CustomReport.first
      expect(rpt.is_a?(CustomReportEntryInvoiceBreakdown)).to be_truthy
      expect(rpt.search_columns.size).to eq(2)
      expect(rpt.search_criterions.size).to eq(1)
      expect(rpt.search_columns.collect {|sc| sc.model_field_uid}).to eq(['bi_brok_ref','bi_entry_num'])
      sp = rpt.search_criterions.first
      expect(sp.model_field_uid).to eq('bi_brok_ref')
      expect(sp.operator).to eq('eq')
      expect(sp.value).to eq('123')
      expect(response).to redirect_to custom_report_path(rpt)
    end
    it "should error if user cannot view report class" do
      allow(CustomReportEntryInvoiceBreakdown).to receive(:can_view?).and_return(false)
      post :create, {:custom_report_type=>'CustomReportEntryInvoiceBreakdown',:custom_report=>{:name=>'ABC'}}
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You do not have permission to use the #{CustomReportEntryInvoiceBreakdown.template_name} report.")
    end
    it "should error if type is not a subclass of CustomReport" do
      post :create, {:custom_report_type=>'String',:custom_report=>{:name=>'ABC'}}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should error if type is not set" do
      post :create, {:custom_report=>{:name=>'ABC'}}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should strip fields user cannot view" do
      allow(ModelField.find_by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      post :create, {:custom_report_type=>'CustomReportEntryInvoiceBreakdown',:custom_report=>
        {:name=>'ABC',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      rpt = CustomReport.first
      expect(rpt.search_columns.size).to eq(1)
      expect(rpt.search_columns.first.model_field_uid).to eq('bi_entry_num')
    end
    it "should strip parameters user cannot view" do
      allow(ModelField.find_by_uid(:bi_brok_ref)).to receive(:can_view?).and_return(false)
      post :create, {:custom_report_type=>'CustomReportEntryInvoiceBreakdown',:custom_report=>
        {:name=>'ABC',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      expect(CustomReport.first.search_criterions).to be_empty
    end
    it "should inject current user's user_id" do
      post :create, {:custom_report_type=>'CustomReportEntryInvoiceBreakdown',:custom_report=>
        {:name=>'ABC',
          :search_columns_attributes=>{'0'=>{:rank=>'0',:model_field_uid=>'bi_brok_ref'},'1'=>{:rank=>'1',:model_field_uid=>'bi_entry_num'}},
          :search_criterions_attributes=>{'0'=>{:model_field_uid=>'bi_brok_ref',:operator=>'eq',:value=>'123'}}
        }
      }
      expect(CustomReport.first.user).to eq(@u)
    end
  end
end
