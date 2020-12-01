describe Plant do
  describe '#search_where' do
    it "should find plant only where user can find company" do
      plant = FactoryBot(:plant)
      plant_not_to_find = FactoryBot(:plant)
      user = FactoryBot(:user, company:plant.company)
      expect(Plant.where(Plant.search_where(user)).to_a).to eq [plant]
    end
  end
  describe "can_view?" do
    it "should allow if user can view company as vendor" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      allow_any_instance_of(Company).to receive(:can_view?).and_return false # to make sure we're not testing the wrong thing
      u = double(:user)
      expect(FactoryBot(:plant).can_view?(u)).to be_truthy
    end
    it "should allow if user can view company" do
      allow_any_instance_of(Company).to receive(:can_view?).and_return true
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false # to make sure we're not testing the wrong thing
      u = double(:user)
      expect(FactoryBot(:plant).can_view?(u)).to be_truthy
    end
    it "should not allow if user cannot view company or company as vendor" do
      allow_any_instance_of(Company).to receive(:can_view?).and_return false
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      u = double(:user)
      expect(FactoryBot(:plant).can_view?(u)).to be_falsey
    end
  end
  describe "can_attach?" do
    it "should allow if user can attach to company" do
      allow_any_instance_of(Company).to receive(:can_attach?).and_return true
      u = double(:user)
      expect(FactoryBot(:plant).can_attach?(u)).to be_truthy
    end
    it "should not allow if user cannot attach to company" do
      allow_any_instance_of(Company).to receive(:can_attach?).and_return false
      u = double(:user)
      expect(FactoryBot(:plant).can_attach?(u)).to be_falsey
    end
  end
  describe "can_edit?" do
    it "should allow if user can edit company" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return true
      u = double(:user)
      expect(FactoryBot(:plant).can_edit?(u)).to be_truthy
    end
    it "should not allow if user cannot edit company" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return false
      u = double(:user)
      expect(FactoryBot(:plant).can_edit?(u)).to be_falsey
    end
  end

  describe "in_use?" do
    it "should return false" do
      expect(Plant.new.in_use?).to be_falsey
    end
    it "should not allow delete if in_use?" do
      plant = FactoryBot(:plant)
      allow(plant).to receive(:in_use?).and_return(true)
      expect {plant.destroy}.to_not change(Plant, :count)
    end
    it "should allow delete if not in_use?" do
      plant = FactoryBot(:plant)
      allow(plant).to receive(:in_use?).and_return(false)
      expect {plant.destroy}.to change(Plant, :count).from(1).to(0)
    end
  end

  describe "unassigned_product_groups" do
    it "shoud return unassigned product groups" do
      plant = FactoryBot(:plant)
      pg1 = FactoryBot(:product_group, name: 'PGA')
      pg2 = FactoryBot(:product_group, name: 'PGB')
      plant.product_groups << pg1
      expect(plant.unassigned_product_groups.to_a).to eq [pg2]
    end
  end
end
