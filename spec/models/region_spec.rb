describe Region do
  context "by_name" do
    it "should sort by name" do
      r1 = Factory(:region, :name=>"B")
      r2 = Factory(:region, :name=>"A")
      expect(Region.by_name.where("1").to_a).to eq([r2, r1])
    end
  end
  context "destroy" do
    it "should destroy associated report objects on destroy based on class count model_field_uid" do
      r = Factory(:region)
      uid =
      col = Factory(:search_column, :model_field_uid=>ModelField.uid_for_region(r, "x"))
      srch = Factory(:search_criterion, :model_field_uid=>ModelField.uid_for_region(r, "y"))
      srt = Factory(:sort_criterion, :model_field_uid=>ModelField.uid_for_region(r, "z"))
      r.destroy
      expect(SearchColumn.exists?(col.id)).to be_falsey
      expect(SearchCriterion.exists?(srch.id)).to be_falsey
      expect(SortCriterion.exists?(srt.id)).to be_falsey
    end
    it "should remove itself from ModelFields" do
      r = Region.create!(:name=>'x')
      expect(ModelField.find_by_region(r).size).to eq(1)
      r.destroy
      expect(ModelField.find_by_region(r).size).to eq(0)
    end
  end
  context "create" do
    it "should reload model fields and include itself" do
      r = Region.create!(:name=>'x')
      expect(ModelField.find_by_region(r).size).to eq(1)
    end
  end
end
