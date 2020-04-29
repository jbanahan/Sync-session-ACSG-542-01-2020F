describe AnswersController do
  describe 'update' do
    before :each do
      @u = Factory(:user)

      sign_in_as @u
      @answer = Factory(:answer)
    end
    it 'should log update' do
      expect_any_instance_of(SurveyResponse).to receive(:assigned_to_user?).with(@u).and_return true
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
      expect_any_instance_of(Answer).to receive(:log_update).with @u
      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
    end

    it 'should allow survey user to save choice' do
      @answer.survey_response.user = @u
      @answer.survey_response.save!
      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
      expect(response).to be_success
      @answer.reload
      expect(@answer.choice).to eq('abc')
    end
    it 'should allow survey group user to save choice' do
      group = Factory(:group)
      @answer.survey_response.group = group
      @answer.survey_response.save!
      @u.groups << group

      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
      expect(response).to be_success
      @answer.reload
      expect(@answer.choice).to eq('abc')
    end
    it 'should allow can_edit? user to save rating' do
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true
      put :update, id: @answer.id, answer:{rating:'abc'}, format: :json
      expect(response).to be_success
      @answer.reload
      expect(@answer.rating).to eq('abc')
    end
    it "should not change choice if user is not the assigned user" do
      @answer.update_attributes(choice:'def')
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true
      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
      expect(response).to be_success
      @answer.reload
      expect(@answer.choice).to eq('def')
    end
    it "should not allow rating to change if user is not able to edit" do
      @answer.update_attributes(rating:'def')
      @answer.survey_response.user = @u
      @answer.survey_response.save!

      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return false
      put :update, id: @answer.id, answer:{rating:'abc'}, format: :json
      expect(response).to be_success
      @answer.reload
      expect(@answer.rating).to eq('def')
    end
    it "should 404 if user cannot view survey" do
      expect {put :update, id: @answer.id, answer:{rating:'abc'}, format: :json}.to raise_error ActionController::RoutingError
    end
    it "does not log updates when the answer choice is not modified" do
      @answer.update_attributes! choice: "abc"
      expect_any_instance_of(SurveyResponse).to receive(:assigned_to_user?).with(@u).and_return true
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
      expect_any_instance_of(Answer).not_to receive(:log_update)
      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
    end

    it "does not log updates when the answer rating is not modified" do
      @answer.update_attributes! rating: "abc"
      expect_any_instance_of(SurveyResponse).to receive(:can_view?).with(@u).and_return true
      expect_any_instance_of(SurveyResponse).to receive(:can_edit?).with(@u).and_return true
      expect_any_instance_of(Answer).not_to receive(:log_update)
      put :update, id: @answer.id, answer:{rating:'abc'}, format: :json
    end
  end
end
