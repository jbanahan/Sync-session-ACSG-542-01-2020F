describe SearchColumn do
  describe 'key_column?' do
    it 'should be a key column' do
      expect(SearchColumn.new(:model_field_uid=>'prod_uid')).to be_key_column
    end
    it 'should not be a key column' do
      expect(SearchColumn.new(:model_field_uid=>'ord_ord_date')).not_to be_key_column
    end
  end

  describe "model_field" do
    let(:sc) { Factory(:search_column, search_setup: Factory(:search_setup, module_type: "Product"), 
                                       model_field_uid: 'prod_uid', constant_field_name: nil, constant_field_value: nil)  }
    
    it "returns MF based on constant field if model_field_uid begins with '_const'" do
      sc.update_attributes! model_field_uid: "_const", constant_field_name: "Whose fault?", constant_field_value: "Vandegrift's"
      mf = sc.model_field
      
      expect(mf.read_only?).to eq true
      expect(mf.label).to eq "Whose fault?"
      expect(mf.qualified_field_name).to eq "(SELECT 'Vandegrift\\'s')"
      expect(mf.export_lambda.call "foo").to eq "Vandegrift's"
      expect(mf.import_lambda.call "foo", "bar", "baz").to eq "Whose fault? is read only."
      expect(mf.blank?).to eq false
    end

    it "MF is considered 'blank' if assigned constant is blank" do
      sc.update_attributes! model_field_uid: "_const", constant_field_name: "Blank", constant_field_value: ""
      mf = sc.model_field
      expect(mf.blank?).to eq true
    end

    it "returns associated MF if model_field_uid doesn't begin with '_const'" do
      sc.model_field
      expect(sc.model_field.label).to eq "Unique Identifier"
    end
  end
end
