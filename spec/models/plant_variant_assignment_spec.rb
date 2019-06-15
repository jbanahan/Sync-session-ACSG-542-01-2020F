describe PlantVariantAssignment do

  # testing search_where and can_view? together because the should enforce
  # same rules at object & db level
  describe '#search_where / can_view?' do
    before :each do
      @vendor = Factory(:vendor)
      @plant = Factory(:plant,company:@vendor)
      @pva = Factory(:plant_variant_assignment,plant:@plant)
      @other_pva = Factory(:plant_variant_assignment)
    end
    it "should find when user can view plant" do
      u = Factory(:user,company:@vendor)
      expect(described_class.where(described_class.search_where(u)).to_a).to eq [@pva]
      expect(@pva.can_view?(u)).to be_truthy
    end
    it "should not find when user cannot view plant" do
      u = Factory(:user)
      expect(described_class.where(described_class.search_where(u)).to_a).to eq []
      expect(@pva.can_view?(u)).to be_falsey
    end
  end
end
