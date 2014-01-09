require 'spec_helper'

describe ProjectDeliverable do
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
