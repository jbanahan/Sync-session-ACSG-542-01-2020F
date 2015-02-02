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
  end
end