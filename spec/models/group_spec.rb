describe Group do
  describe "visible_to_user" do
    before :each do
      @master_only = Factory(:group)
    end
    it "should show all to master" do
      expect(Group.visible_to_user(Factory(:master_user)).to_a).to eq [@master_only]
    end
    it "should show user groups he is in" do
      u = Factory(:user)
      g2 = Factory(:group)
      g2.users << u
      expect(Group.visible_to_user(u).to_a).to eq [g2]
    end
    it "should show user groups other users from same company are in" do
      u = Factory(:user)
      g2 = Factory(:group)
      g2.users << Factory(:user, company:u.company)
      expect(Group.visible_to_user(u).to_a).to eq [g2]
    end
    it "should show user groups other users from linked company are in" do
      u = Factory(:user)
      u2 = Factory(:user)
      g2 = Factory(:group)
      g2.users << u2
      u.company.linked_companies << u2.company
      expect(Group.visible_to_user(u).to_a).to eq [g2]
    end
    it "should validate presence of name" do
      g = Group.new(name: "")
      g.save
      expect(g.errors.messages[:name]).to include "can't be blank"
    end
    it "should validate presence of system_code" do
      g = Group.new
      g.save
      expect(g.errors.messages[:system_code]).to include "can't be blank"
    end
    it "should validate uniqueness of system_code, if it exists" do
      Factory(:group, system_code: "ABCDE")
      g = Group.new(name: "g2", system_code: "ABCDE")
      g.save
      expect(g.errors.messages.count).to eq 1
      expect(g.errors.messages[:system_code]).to include "has already been taken"
    end
  end

  describe "use_system_group" do
    it "creates system group when not present" do
      g = Group.use_system_group "CODE", name: "Group"
      expect(g).to be_persisted
      expect(g.system_code).to eq "CODE"
      expect(g.name).to eq "Group"
      expect(g.description).to eq nil
    end

    it "creates system group when not present and sets description" do
      g = Group.use_system_group "CODE", name: "Group", description: "This is the group description."
      expect(g).to be_persisted
      expect(g.system_code).to eq "CODE"
      expect(g.name).to eq "Group"
      expect(g.description).to eq "This is the group description."
    end

    it "does not create group if told not to" do
      expect(Group.use_system_group "CODE", name: "Group", create: false).to be_nil
    end

    it "uses existing group" do
      g = Group.create! system_code: "CODE", name: "Name", description: "Old description"
      found = Group.use_system_group "CODE", name: "Another Name" , description: "New description"
      expect(found).to eq g
      expect(found.name).to eq "Name"
      expect(found.description).to eq "Old description"
    end
  end

  describe "user_emails" do
    let (:group) { Group.use_system_group "TEST", name: "Test" }
    let! (:user_1) {
      u = Factory(:user, email: "me@there.com")
      group.users << u
      u
    }

    let! (:user_2) {
      u = Factory(:user, email: "you@there.com")
      group.users << u
      u
    }

    it "returns all users emails addresses that are part of the group" do
      emails = group.user_emails
      expect(emails.length).to eq 2
      expect(emails).to include "me@there.com"
      expect(emails).to include "you@there.com"
    end

    it "does not return any blank emails" do
      user_1.update_attributes! email: ""
      emails = group.user_emails

      expect(emails.length).to eq 1
      expect(emails).to include "you@there.com"
    end
  end
end
