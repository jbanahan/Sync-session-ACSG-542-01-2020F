require 'spec_helper'

describe CorrectiveActionPlansController do
  before :each do
    activate_authlogic
    @u = Factory(:user)
    UserSession.create! @u
  end
  describe :show do
    before :each do
      @cap = Factory(:corrective_action_plan)
    end
    it "should show if you can view" do
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return true
      get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s
      response.should be_success
      assigns(:cap).should == @cap
    end
    it "should not show if cannot view" do
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return false 
      get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s
      response.should be_redirect
      assigns(:cap).should be_nil
    end
    context :json do
      before :each do
        CorrectiveActionPlan.any_instance.stub(:can_view?).and_return true
      end
      it "should render json" do
        get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, format: 'json'
        r = JSON.parse(response.body)
        r['corrective_action_plan']['id'].should == @cap.id
      end
      it "should include html rendered comments" do
        comm = @cap.comments.create!(body:'*my text*',user_id:@u.id)
        get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, format: 'json'
        r = JSON.parse(response.body)
        c = r['corrective_action_plan']['comments'].first
        c['html_body'].should == RedCloth.new('*my text*').to_html
      end
    end
  end
  describe :update do
    before :each do
      @cap = Factory(:corrective_action_plan)
      @sr_id = @cap.survey_response_id
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return(true)
    end
    it "should add comment if it exists" do
      post :update, survey_response_id:@sr_id.to_s, id:@cap.id.to_s, comment:'my comment', format: 'json'
      response.should be_success 
      @cap.reload
      c = @cap.comments.first
      c.user.should == @u
      c.body.should == 'my comment'
    end
    it "should not add comment if it doesn't exist" do
      post :update, survey_response_id:@sr_id.to_s, id:@cap.id.to_s, comment:'', format: 'json'
      response.should be_success 
      @cap.reload
      @cap.comments.should be_blank
    end
    it "should not add comment if user cannot view" do
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return(false)
      post :update, survey_response_id:@sr_id.to_s, id:@cap.id.to_s, comment:'my comment', format: 'json'
      @cap.reload
      @cap.comments.should be_empty
    end
    it "should update nested issues for editor" do
      ci = @cap.corrective_issues.create!(description:'d',suggested_action:'sa',action_taken:'at')
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(true)
      CorrectiveActionPlan.any_instance.stub(:can_update_actions?).and_return(false)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, 'corrective_action_plan'=>{'corrective_issues'=>[{'id'=>ci.id.to_s,'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}]}, :format=> 'json'
      response.should be_success 
      @cap.reload
      @cap.should have(1).corrective_issues
      ci.reload
      ci.description.should == 'nd'
      ci.suggested_action.should == 'ns'
      ci.action_taken.should == 'at' #not updated because of permissions
    end
    it "should update nested issues for asssigned user" do
      ci = @cap.corrective_issues.create!(description:'d',suggested_action:'sa',action_taken:'at')
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(false)
      CorrectiveActionPlan.any_instance.stub(:can_update_actions?).and_return(true)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, 'corrective_action_plan'=>{'corrective_issues'=>[{'id'=>ci.id.to_s,'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}]}, :format=> 'json'
      response.should be_success 
      @cap.reload
      @cap.should have(1).corrective_issues
      ci.reload
      ci.action_taken.should == 'na'
      ci.description.should == 'd' #not updated because of permissions
      ci.suggested_action.should == 'sa' #not updated because of permissions
    end
    it "should create issues for editor" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(true)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, 'corrective_action_plan'=>{'corrective_issues'=>[{'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}]}, :format=> 'json'
      @cap.should have(1).corrective_issues
      ci = @cap.corrective_issues.first
      ci.description.should == 'nd'
      ci.suggested_action.should == 'ns'
    end
    it "should not create issues for user who can't edit" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(false)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, 'corrective_action_plan'=>{'corrective_issues'=>[{'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}]}, :format=> 'json'
      @cap.reload
      @cap.corrective_issues.should be_empty
    end
    it "should trigger email when status is Active" do
      Delayed::Worker.delay_jobs = false
      @cap.status = CorrectiveActionPlan::STATUSES[:active]
      @cap.save!
      ds = double('deliver stub')
      ds.stub(:deliver)
      OpenMailer.should_receive(:send_survey_user_update).with(@cap.survey_response,true).and_return(ds)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, 'corrective_action_plan'=>{'corrective_issues'=>[{'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}]}, :format=> 'json'
    end
    it "should not trigger email when status is not active" do
      Delayed::Worker.delay_jobs = false
      @cap.status = CorrectiveActionPlan::STATUSES[:new]
      @cap.save!
      OpenMailer.should_not_receive(:send_survey_user_update)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, 'corrective_action_plan'=>{'corrective_issues'=>[{'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}]}, :format=> 'json'
    end
  end
  describe :create do
    before :each do
      @sr = Factory(:survey_response)
    end
    it "should fail if user cannot edit survey_response" do
      post :create, survey_response_id:@sr.id.to_s
      response.should be_redirect
      CorrectiveActionPlan.all.should be_empty
    end
    it "should succeed if user can edit survey_response" do
      SurveyResponse.any_instance.stub(:can_edit?).and_return true
      post :create, survey_response_id:@sr.id.to_s
      @sr.reload
      cap = @sr.corrective_action_plan
      cap.should_not be_nil
      response.should redirect_to [@sr,cap]
    end
  end
  describe :activate do
    before :each do 
      @cap = Factory(:corrective_action_plan)
    end
    it "should activate if user can edit" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(true)
      put :activate, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      response.should redirect_to [@cap.survey_response,@cap]
      @cap.reload
      @cap.status.should == CorrectiveActionPlan::STATUSES[:active]
    end
    it "should not activate if user cannot edit" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(false)
      put :activate, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      response.should be_redirect 
      flash[:errors].first.should == "You cannot activate this plan."
      @cap.reload
      @cap.status.should == CorrectiveActionPlan::STATUSES[:new]
    end
    it 'should trigger email to assigned' do
      Delayed::Worker.delay_jobs = false
      ds = double('deliver stub')
      ds.stub(:deliver)
      OpenMailer.should_receive(:send_survey_user_update).with(@cap.survey_response,true).and_return(ds)
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(true)
      put :activate, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
    end
  end
  describe :resolve do
    before :each do 
      @cap = Factory(:corrective_action_plan)
    end
    it "should resolve if user can edit" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(true)
      put :resolve, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      response.should redirect_to [@cap.survey_response,@cap]
      @cap.reload
      @cap.status.should == CorrectiveActionPlan::STATUSES[:resolved]
    end
    it "should not resolve if user cannot edit" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(false)
      put :resolve, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      response.should be_redirect 
      flash[:errors].first.should == "You cannot resolve this plan."
      @cap.reload
      @cap.status.should == CorrectiveActionPlan::STATUSES[:new]
    end
  end
  describe :destroy do
    before :each do
      @cap = Factory(:corrective_action_plan)
    end
    it "should allow if user can delete" do
      CorrectiveActionPlan.any_instance.stub(:can_delete?).and_return(true)
      delete :destroy, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      CorrectiveActionPlan.find_by_id(@cap.id).should be_nil
    end
    it "shouldn't allow if user cannot delete" do
      CorrectiveActionPlan.any_instance.stub(:can_delete?).and_return(false)
      delete :destroy, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      CorrectiveActionPlan.find_by_id(@cap.id).should_not be_nil
    end
  end
end
