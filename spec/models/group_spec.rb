require 'spec_helper'

describe Group do
  describe :visible_to_user do
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
      g2.users << Factory(:user,company:u.company)
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
      expect(g.errors.messages.count).to eq 1
      expect(g.errors.messages[:name]).to include "can't be blank"
    end
    it "should validate uniqueness of system_code, if it exists" do
      Factory(:group, system_code: "ABCDE")
      g = Group.new(name: "g2", system_code: "ABCDE")
      g.save
      expect(g.errors.messages.count).to eq 1
      expect(g.errors.messages[:system_code]).to include "has already been taken"
    end
  end
end