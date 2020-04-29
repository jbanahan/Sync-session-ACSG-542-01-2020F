describe CorrectiveActionPlansController do
  before :each do

    @u = Factory(:user, first_name:'joe', last_name:'user')
    sign_in_as @u
  end
  describe "add_comment" do
    before :each do
      @cap = Factory(:corrective_action_plan)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return true
    end
    it "should fail if user cannot view" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return false
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      expect(response.status).to eq(401)
      expect(@cap.comments).to be_empty
    end
    it "should add comment and return comment json" do
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      expect(response).to be_success
      c = @cap.comments.first
      expect(c.user).to eq(@u)
      expect(c.body).to eq('xyz')
      j = JSON.parse(response.body)['comment']
      expect(j['id']).to eq(c.id)
      expect(j['html_body']).to eq('<p>xyz</p>')
      expect(j['user']['full_name']).to eq(@u.full_name)
    end
    it "should ignore blank submissions" do
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'', format: :json
      expect(response.status).to eq(400)
      j = expect(JSON.parse(response.body)['error']).to eq('Empty comment not added')
      expect(@cap.comments).to be_empty
    end
    it "should log update if not new" do
      @cap.update_attributes(status: CorrectiveActionPlan::STATUSES[:active])
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      expect(response).to be_success
      sru = SurveyResponseUpdate.first
      expect(sru.survey_response).to eq(@cap.survey_response)
      expect(sru.user).to eq(@u)
    end
    it "should not log update if new" do
      @cap.update_attributes(status: CorrectiveActionPlan::STATUSES[:new])
      post :add_comment, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, comment:'xyz', format: :json
      expect(response).to be_success
      expect(SurveyResponseUpdate.all).to be_empty
    end
  end
  describe "show" do
    before :each do
      @cap = Factory(:corrective_action_plan)
    end
    it "should show if you can view" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return true
      get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(response).to be_success
      expect(assigns(:cap)).to eq(@cap)
    end
    it "should not show if cannot view" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return false
      get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(response).to be_redirect
      expect(assigns(:cap)).to be_nil
    end
    context "json" do
      before :each do
        allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return true
      end
      it "should render json" do
        get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, format: 'json'
        r = JSON.parse(response.body)
        expect(r['corrective_action_plan']['id']).to eq(@cap.id)
      end
      it "should include html rendered comments" do
        comm = @cap.comments.create!(body:'*my text*', user_id:@u.id)
        get :show, survey_response_id: @cap.survey_response_id.to_s, id: @cap.id.to_s, format: 'json'
        r = JSON.parse(response.body)
        c = r['corrective_action_plan']['comments'].first
        expect(c['html_body']).to eq(RedCloth.new('*my text*').to_html)
      end
    end
  end
  describe "update" do
    before :each do
      @cap = Factory(:corrective_action_plan)
      @sr_id = @cap.survey_response_id
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return(true)
    end
    it "should add comment if it exists" do
      post :update, survey_response_id:@sr_id.to_s, id:@cap.id.to_s, comment:'my comment', format: 'json'
      expect(response).to be_success
      @cap.reload
      c = @cap.comments.first
      expect(c.user).to eq(@u)
      expect(c.body).to eq('my comment')
    end
    it "should not add comment if it doesn't exist" do
      post :update, survey_response_id:@sr_id.to_s, id:@cap.id.to_s, comment:'', format: 'json'
      expect(response).to be_success
      @cap.reload
      expect(@cap.comments).to be_blank
    end
    it "should not add comment if user cannot view" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return(false)
      post :update, survey_response_id:@sr_id.to_s, id:@cap.id.to_s, comment:'my comment', format: 'json'
      @cap.reload
      expect(@cap.comments).to be_empty
    end
    it "should log update" do
      expect_any_instance_of(CorrectiveActionPlan).to receive(:log_update).with(@u)
      post :update, :survey_response_id=>@sr_id.to_s, :id=>@cap.id.to_s, :comment=>'xyz', :format=> 'json'
    end
  end
  describe "create" do
    before :each do
      @sr = Factory(:survey_response)
    end
    it "should fail if user cannot edit survey_response" do
      post :create, survey_response_id:@sr.id.to_s
      expect(response).to be_redirect
      expect(CorrectiveActionPlan.all).to be_empty
    end
    it "should succeed if user can edit survey_response" do
      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true
      post :create, survey_response_id:@sr.id.to_s
      @sr.reload
      cap = @sr.corrective_action_plan
      expect(cap).not_to be_nil
      expect(response).to redirect_to [@sr, cap]
    end
  end
  describe "activate" do
    before :each do
      @cap = Factory(:corrective_action_plan)
    end
    it "should activate if user can edit" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(true)
      put :activate, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(response).to redirect_to [@cap.survey_response, @cap]
      @cap.reload
      expect(@cap.status).to eq(CorrectiveActionPlan::STATUSES[:active])
    end
    it "should not activate if user cannot edit" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(false)
      put :activate, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You cannot activate this plan.")
      @cap.reload
      expect(@cap.status).to eq(CorrectiveActionPlan::STATUSES[:new])
    end
    it 'should log update' do
      expect_any_instance_of(CorrectiveActionPlan).to receive(:log_update).with(@u)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(true)
      put :activate, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
    end
  end
  describe "resolve" do
    before :each do
      @cap = Factory(:corrective_action_plan)
    end
    it "should resolve if user can edit" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(true)
      put :resolve, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(response).to redirect_to [@cap.survey_response, @cap]
      @cap.reload
      expect(@cap.status).to eq(CorrectiveActionPlan::STATUSES[:resolved])
    end
    it "should not resolve if user cannot edit" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(false)
      put :resolve, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq("You cannot resolve this plan.")
      @cap.reload
      expect(@cap.status).to eq(CorrectiveActionPlan::STATUSES[:new])
    end
  end
  describe "destroy" do
    before :each do
      @cap = Factory(:corrective_action_plan)
    end
    it "should allow if user can delete" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_delete?).and_return(true)
      delete :destroy, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(CorrectiveActionPlan.find_by_id(@cap.id)).to be_nil
    end
    it "shouldn't allow if user cannot delete" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_delete?).and_return(false)
      delete :destroy, survey_response_id:@cap.survey_response_id.to_s, id: @cap.id.to_s
      expect(CorrectiveActionPlan.find_by_id(@cap.id)).not_to be_nil
    end
  end
end
