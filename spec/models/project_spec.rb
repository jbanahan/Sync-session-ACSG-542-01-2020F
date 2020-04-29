describe Project do
  context "security" do
    describe "can_view?" do
      it "should be able to view if user can view projects" do
        u = User.new
        expect(u).to receive(:view_projects?).and_return true
        expect(Project.new.can_view?(u)).to be_truthy
      end
      it "should not be able to view if user can view projects" do
        u = User.new
        expect(u).to receive(:view_projects?).and_return false
        expect(Project.new.can_view?(u)).to be_falsey
      end
    end
    describe "can_edit?" do
      it "should be able to edit if user can edit projects" do
        u = User.new
        expect(u).to receive(:edit_projects?).and_return true
        expect(Project.new.can_edit?(u)).to be_truthy
      end
      it "should not be able to edit if user can edit projects" do
        u = User.new
        expect(u).to receive(:edit_projects?).and_return false
        expect(Project.new.can_edit?(u)).to be_falsey
      end
    end
  end
  describe "red?" do
    it "should be red if there are red_messages" do
      p = Project.new()
      allow(p).to receive(:red_messages).and_return ['abc']
      expect(p).to be_red
    end
    it "should not be red if there are not red_messages" do
      p = Project.new()
      allow(p).to receive(:red_messages).and_return []
      expect(p).not_to be_red
    end
  end
  describe "red_messages" do
    it "should not have message if closed" do
      expect(Project.new(closed_at:Time.now, due:2.weeks.ago).red_messages).to be_blank
    end
    it "should have message if no active milestones" do
      expect(Project.new.red_messages.to_a).to eq ["Project doesn't have any open deliverables."]
    end
    it "should have message if not updated in 10 days" do
      p = Project.new
      p.updated_at = 11.days.ago
      expect(p.red_messages.join).to match /more than 10 days/
    end
    it "should be red if due in the past" do
      expect(Project.new(due:1.day.ago).red_messages.join).to match /overdue/
    end
    it "should be red if any incomplete tasks exist" do
      d = Factory(:project_deliverable, due_date:1.day.ago)
      expect(d.project.red_messages.join).to match /1 deliverable overdue/
    end
  end
end
