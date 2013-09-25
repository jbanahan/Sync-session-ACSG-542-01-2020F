require 'spec_helper'

describe CorrectiveActionPlan do
  before :each do
    @cap = Factory(:corrective_action_plan)
    @u = Factory(:user) 
  end
  describe :can_update_actions? do
    it "should allow if user == survey_response.user" do
      sr = @cap.survey_response
      sr.user = @u
      sr.save!
      @cap.can_update_actions?(@u).should be_true
    end
    it "should not allow if user != survey_response.user" do
      @cap.can_update_actions?(@u).should be_false
    end
  end
  describe :can_view? do
    it "should allow if you can view the survey response" do
      @cap.survey_response.should_receive(:can_view?).with(@u).and_return true
      @cap.can_view?(@u).should be_true
    end
    it "should not allow if you are the survey response user, cannot edit the response and the status is 'New'" do
      @cap.status = described_class::STATUSES[:new]
      sr = @cap.survey_response
      sr.user = @u
      sr.save!
      @cap.survey_response.stub(:can_view?).and_return true
      @cap.survey_response.stub(:can_edit?).and_return false 
      @cap.can_view?(@u).should be_false
    end
    it "should not allow if you can't view the survey response" do
      @cap.survey_response.should_receive(:can_view?).with(@u).and_return false
      @cap.can_view?(@u).should be_false
    end
  end
  describe :can_edit? do
    it "should allow edit if user can edit survey_response" do
      @cap.survey_response.should_receive(:can_edit?).with(@u).and_return true
      @cap.can_edit?(@u).should be_true
    end
    it "should not allow edit if user cannot edit survey_response" do
      @cap.survey_response.should_receive(:can_edit?).with(@u).and_return false
      @cap.can_edit?(@u).should be_false
    end
  end
  describe :can_delete do
    it "should allow delete if status is new && user can edit" do
      @cap.status = described_class::STATUSES[:new]
      @cap.should_receive(:can_edit?).and_return(true)
      @cap.can_delete?(@u).should be_true
    end
    it "shouldn't allow delete if status is not new" do
      @cap.status = described_class::STATUSES[:active]
      @cap.stub(:can_edit?).and_return(true)
      @cap.can_delete?(@u).should be_false
    end
    it "shouldn't allow delete if user cannot edit" do
      @cap.status = described_class::STATUSES[:new]
      @cap.should_receive(:can_edit?).and_return(false)
      @cap.can_delete?(@u).should be_false
    end
  end
  describe :destroy do
    it "should not allow destroy if status not new or nil" do
      @cap.status = described_class::STATUSES[:active]
      @cap.destroy
      @cap.should_not be_destroyed
    end
    it "should allow destroy if status == New" do
      @cap.status = described_class::STATUSES[:new]
      @cap.destroy
      @cap.should be_destroyed
    end
    it "should allow destroy if status.blank?" do
      @cap.status = nil 
      @cap.destroy
      @cap.should be_destroyed
    end
  end
  describe :status do
    it "should set status on create" do
      Factory(:survey_response).create_corrective_action_plan!.status.should == described_class::STATUSES[:new]
    end
  end
end
