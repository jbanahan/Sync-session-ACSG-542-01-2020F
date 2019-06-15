describe CorrectiveActionPlan do
  before :each do
    @cap = Factory(:corrective_action_plan)
    @u = Factory(:user) 
  end
  describe "log_update" do
    it "should log against survey_response if cap is active" do
      @cap.status = described_class::STATUSES[:active]
      expect(@cap.survey_response).to receive(:log_update).with @u
      @cap.log_update @u
    end
    it "should not log against survey_response if cap is inactive" do
      @cap.status = described_class::STATUSES[:new]
      expect(@cap.survey_response).not_to receive(:log_update).with @u
      @cap.log_update @u
    end
  end
  describe "can_update_actions?" do
    it "should allow if user == survey_response.user" do
      sr = @cap.survey_response
      sr.user = @u
      sr.save!
      expect(@cap.can_update_actions?(@u)).to be_truthy
    end
    it "should not allow if user != survey_response.user" do
      expect(@cap.can_update_actions?(@u)).to be_falsey
    end
  end
  describe "can_view?" do
    it "should allow if you can view the survey response" do
      expect(@cap.survey_response).to receive(:can_view?).with(@u).and_return true
      expect(@cap.can_view?(@u)).to be_truthy
    end
    it "should not allow if you are the survey response user, cannot edit the response and the status is 'New'" do
      @cap.status = described_class::STATUSES[:new]
      sr = @cap.survey_response
      sr.user = @u
      sr.save!
      allow(@cap.survey_response).to receive(:can_view?).and_return true
      allow(@cap.survey_response).to receive(:can_edit?).and_return false 
      expect(@cap.can_view?(@u)).to be_falsey
    end
    it "should not allow if you can't view the survey response" do
      expect(@cap.survey_response).to receive(:can_view?).with(@u).and_return false
      expect(@cap.can_view?(@u)).to be_falsey
    end
  end
  describe "can_edit?" do
    it "should allow edit if user can edit survey_response" do
      expect(@cap.survey_response).to receive(:can_edit?).with(@u).and_return true
      expect(@cap.can_edit?(@u)).to be_truthy
    end
    it "should not allow edit if user cannot edit survey_response" do
      expect(@cap.survey_response).to receive(:can_edit?).with(@u).and_return false
      expect(@cap.can_edit?(@u)).to be_falsey
    end
  end
  describe "can_delete" do
    it "should allow delete if status is new && user can edit" do
      @cap.status = described_class::STATUSES[:new]
      expect(@cap).to receive(:can_edit?).and_return(true)
      expect(@cap.can_delete?(@u)).to be_truthy
    end
    it "shouldn't allow delete if status is not new" do
      @cap.status = described_class::STATUSES[:active]
      allow(@cap).to receive(:can_edit?).and_return(true)
      expect(@cap.can_delete?(@u)).to be_falsey
    end
    it "shouldn't allow delete if user cannot edit" do
      @cap.status = described_class::STATUSES[:new]
      expect(@cap).to receive(:can_edit?).and_return(false)
      expect(@cap.can_delete?(@u)).to be_falsey
    end
  end
  describe "destroy" do
    it "should not allow destroy if status not new or nil" do
      @cap.status = described_class::STATUSES[:active]
      @cap.destroy
      expect(@cap).not_to be_destroyed
    end
    it "should allow destroy if status == New" do
      @cap.status = described_class::STATUSES[:new]
      @cap.destroy
      expect(@cap).to be_destroyed
    end
    it "should allow destroy if status.blank?" do
      @cap.status = nil 
      @cap.destroy
      expect(@cap).to be_destroyed
    end
  end
  describe "status" do
    it "should set status on create" do
      expect(Factory(:survey_response).create_corrective_action_plan!.status).to eq(described_class::STATUSES[:new])
    end
  end
end
