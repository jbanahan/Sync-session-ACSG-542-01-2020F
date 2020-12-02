describe OpenChain::ModelFieldDefinition::PlantVariantAssignmentFieldDefinition do
  context "foreign key relationships" do
    before :each do
      @vendor = create(:vendor, name:'ABCVendor')
      @user = create(:user, company:@vendor)
      @plant = create(:plant, name:'ABCPlant', company:@vendor)
      @product = create(:product, name:'ABCProduct', unique_identifier:'ABC123')
      @variant = create(:variant, variant_identifier:'ABCVariant', product:@product)
      @pva = PlantVariantAssignment.create!(variant:@variant, plant:@plant)
    end
    def find_keys_by_search_criterion model_field, val
      ss = SearchSetup.new(module_type:'PlantVariantAssignment', user:@user)
      sc = ss.search_criterions.build(model_field_uid:model_field.uid, operator:'eq', value:val)
      return SearchQuery.new(ss, @user).result_keys
    end
    it "should get plant name" do
      mf = ModelField.find_by_uid(:pva_plant_name)
      expect(find_keys_by_search_criterion(mf, @plant.name)).to eq [@pva.id]
      expect(mf.process_export(@pva, @user)).to eq @plant.name
    end
    it "should get company name" do
      mf = ModelField.find_by_uid(:pva_company_name)
      expect(find_keys_by_search_criterion(mf, @vendor.name)).to eq [@pva.id]
      expect(mf.process_export(@pva, @user)).to eq @vendor.name
    end
    it "should get variant identifier" do
      mf = ModelField.find_by_uid(:pva_var_identifier)
      expect(find_keys_by_search_criterion(mf, @variant.variant_identifier)).to eq [@pva.id]
      expect(mf.process_export(@pva, @user)).to eq @variant.variant_identifier
    end
    it "should get product unique identifier" do
      mf = ModelField.find_by_uid(:pva_prod_uid)
      expect(find_keys_by_search_criterion(mf, @product.unique_identifier)).to eq [@pva.id]
      expect(mf.process_export(@pva, @user)).to eq @product.unique_identifier
    end
    it "should get product name" do
      mf = ModelField.find_by_uid(:pva_prod_name)
      expect(find_keys_by_search_criterion(mf, @product.name)).to eq [@pva.id]
      expect(mf.process_export(@pva, @user)).to eq @product.name
    end
  end
end