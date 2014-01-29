require 'spec_helper'

describe ProjectDeliverable do
  describe :not_closed do
    it "should not return closed deliverables" do
      d1 = Factory(:project_deliverable)
      d2 = Factory(:project_deliverable,project:Factory(:project,closed_at:Time.now))
      expect(ProjectDeliverable.not_closed.to_a).to eq [d1]
    end
  end
  context :security do
    it "should allow view if project is visible" do
      pd = Factory(:project_deliverable)
      pd.project.stub(:can_view?).and_return true
      expect(pd.can_view?(User.new)).to be_true
    end
    it "should allow edit if project is editable" do
      pd = Factory(:project_deliverable)
      pd.project.stub(:can_edit?).and_return true
      expect(pd.can_edit?(User.new)).to be_true
    end
    it "should not allow view if project is not visible" do
      pd = Factory(:project_deliverable)
      pd.project.stub(:can_view?).and_return false
      expect(pd.can_view?(User.new)).to be_false
    end
    it "should not allow edit if project is not editable" do
      pd = Factory(:project_deliverable)
      pd.project.stub(:can_edit?).and_return false
      expect(pd.can_edit?(User.new)).to be_false
    end
  end
end
