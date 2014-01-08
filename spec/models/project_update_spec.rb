require 'spec_helper'

describe ProjectUpdate do
  context :security do
    it "should allow view if project is visible" do
      pu = Factory(:project_update)
      pu.project.stub(:can_view?).and_return true
      expect(pu.can_view?(User.new)).to be_true
    end
    it "should allow edit if project is editable" do
      pu = Factory(:project_update)
      pu.project.stub(:can_edit?).and_return true
      expect(pu.can_edit?(User.new)).to be_true
    end
    it "should not allow view if project is not visible" do
      pu = Factory(:project_update)
      pu.project.stub(:can_view?).and_return false
      expect(pu.can_view?(User.new)).to be_false
    end
    it "should not allow edit if project is not editable" do
      pu = Factory(:project_update)
      pu.project.stub(:can_edit?).and_return false
      expect(pu.can_edit?(User.new)).to be_false
    end
  end
end
