require 'spec_helper'

describe CorrectiveActionPlansController do
  before :each do

    @u = Factory(:user,first_name:'joe',last_name:'user')
    sign_in_as @u
  end
  describe :add_comment do
    before :each do
      @cap = Factory(:corrective_action_plan)
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return true 
    end
    it "should fail if user cannot view" do
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return false 
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      response.status.should == 401
      @cap.comments.should be_empty
    end
    it "should add comment and return comment json" do
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      response.should be_success
      c = @cap.comments.first
      c.user.should == @u
      c.body.should == 'xyz'
      j = JSON.parse(response.body)['comment']
      j['id'].should == c.id
      j['html_body'].should == '<p>xyz</p>'
      j['user']['full_name'].should == @u.full_name
    end
    it "should ignore blank submissions" do
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'', format: :json
      response.status.should == 400
      j = JSON.parse(response.body)['error'].should == 'Empty comment not added'
      @cap.comments.should be_empty
    end
    it "should log update if not new" do
      @cap.update_attributes(status: CorrectiveActionPlan::STATUSES[:active])
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      response.should be_success
      sru = SurveyResponseUpdate.first
      sru.survey_response.should == @cap.survey_response
      sru.user.should == @u
    end
    it "should not log update if new" do
      @cap.update_attributes(status: CorrectiveActionPlan::STATUSES[:new])
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      response.should be_success
      SurveyResponseUpdate.all.should be_empty
    end
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
    it "should log update" do
      CorrectiveActionPlan.any_instance.should_receive(:log_update).with(@u)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, :comment=>'xyz', :format=> 'json'
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
    it 'should log update' do
      CorrectiveActionPlan.any_instance.should_receive(:log_update).with(@u)
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
