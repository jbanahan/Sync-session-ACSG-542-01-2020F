describe HoldsCustomDefinition do
  
  context "custom_definition" do
    before :each do
      @cd = Factory(:custom_definition,:module_type=>"Product")
      ModelField.reset_custom_fields
      @cfid = "*cf_#{@cd.id}"
    end
    context "model_field_uid" do
      it "should set id" do
        [SearchColumn,SearchCriterion,SortCriterion].each do |k|
          sc = k.new
          sc.model_field_uid = @cfid
          expect(sc).to be_custom_field
          expect(sc.custom_definition_id).to eq(@cd.id)
        end
      end
    end
    context "before_save" do
      it "should associate on save" do
        [:search_column,:search_criterion,:sort_criterion].each do |k|
          sc = Factory(k,:model_field_uid=>@cfid)
          sc.save!
          expect(sc.custom_definition).to eq(@cd)
        end
      end
    end
  end
end
