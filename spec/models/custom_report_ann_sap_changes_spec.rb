describe CustomReportAnnSapChanges do
  before :each do
    @u = FactoryBot(:master_user)
    allow_any_instance_of(MasterSetup).to receive(:custom_feature?).and_return(true)
  end
  describe "static_methods" do
    it "should not allow users not from master company" do
      allow_any_instance_of(Company).to receive(:master?).and_return(false)
      expect(described_class.can_view?(@u)).to be_falsey
    end
    it "should not allow if Ann SAP not enabled" do
      expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('Ann SAP').and_return(false)
      expect(described_class.can_view?(@u)).to be_falsey
    end
    it "should allow product, classification fields" do
      avail = described_class.column_fields_available(@u)
      expect(avail).to include(ModelField.find_by_uid(:prod_uid))
      expect(avail).to include(ModelField.find_by_uid(:class_cntry_iso))
    end
    it "should allow parameters from product, classifcation" do
      avail = described_class.criterion_fields_available(@u)
      expect(avail).to include(ModelField.find_by_uid(:prod_uid))
      expect(avail).to include(ModelField.find_by_uid(:class_cntry_iso))
    end

  end

  describe "run" do
    def make_eligible_product
      tr = FactoryBot(:tariff_record)
      cls = tr.classification
      cls.update_custom_value! @appr, 2.days.ago
      cls.product.update_custom_value! @sap, 1.day.ago
      cls.product
    end
    before :each do
      @rc = described_class.new
      @rc.search_columns.build(:model_field_uid=>:prod_uid, :rank=>1)
      @rc.search_columns.build(:model_field_uid=>:class_cntry_iso, :rank=>2)
      @cdefs = described_class.prep_custom_definitions OpenChain::CustomHandler::AnnInc::AnnSapProductHandler::SAP_REVISED_PRODUCT_FIELDS + [:sap_revised_date, :approved_date]
      @appr = @cdefs[:approved_date]
      @sap = @cdefs[:sap_revised_date]
    end
    it "should only include products with SAP Revised Date after approved date" do
      p = make_eligible_product
      tr2 = FactoryBot(:tariff_record)
      cls2 = tr2.classification
      cls2.update_custom_value! @appr, 2.days.ago
      cls2.product.update_custom_value! @sap, 3.days.ago
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      expect(arrays[1][0]).to eq(p.unique_identifier)
      expect(arrays[1][1]).to eq(p.classifications.first.country.iso_code)
    end
    it "should write difference columns", :snapshot do
      p = make_eligible_product
      diffs = [:origin, :import, :related_styles, :cost]
      diffs.each {|d| p.update_custom_value! @cdefs[d], "OLD-#{d}" }
      es = p.create_snapshot @u
      es.update_attributes(created_at:3.days.ago)
      diffs.each {|d| p.update_custom_value! @cdefs[d], "NEW-#{d}" }
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      row = arrays[1]
      diffs.each_with_index do |d, i|
        new_val = row[3+(i*2)]
        expect(new_val).to eq("NEW-#{d}")

        old_val = row[2+(i*2)]
        expect(old_val).to eq("OLD-#{d}")
      end
    end
    it "should include web links" do
      @rc.include_links = true
      @rc.include_rule_links = true
      p = make_eligible_product
      arrays = @rc.to_arrays @u
      expect(arrays[1][0]).to eq("http://localhost:3000/products/#{p.id}")
      expect(arrays[1][1]).to eq "http://localhost:3000/products/#{p.id}/validation_results"
      expect(arrays[1][2]).to eq(p.unique_identifier)
    end
    it "should not include classification with approval after sap revised date even if another classification is before" do
      p = make_eligible_product
      cls = FactoryBot(:classification, product:p)
      cls.update_custom_value! @appr, 0.days.ago
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      expect(arrays[1][1]).to eq(p.classifications.first.country.iso_code)
    end
    it "should filter on extra parameters" do
      find_me = make_eligible_product
      dont_find_me = make_eligible_product
      @rc.search_criterions.build(model_field_uid:'prod_uid', operator:'eq', value:find_me.unique_identifier)
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      expect(arrays[1][0]).to eq(find_me.unique_identifier)
    end
    it "should handle records with no snapshots" do
      p = make_eligible_product
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      expect(arrays[1][2]).to eq("")
    end
    it "should handle records with no snapshots before approved date", :snapshot do
      p = make_eligible_product
      diffs = [:origin, :import, :related_styles, :cost]
      diffs.each {|d| p.update_custom_value! @cdefs[d], "OLD-#{d}" }
      es = p.create_snapshot @u
      diffs.each {|d| p.update_custom_value! @cdefs[d], "NEW-#{d}" }
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      expect(arrays[1][2]).to eq("")
    end
    it "should use most recent snapshot before approved date", :snapshot do
      p = make_eligible_product
      diffs = [:origin, :import, :related_styles, :cost]
      diffs.each {|d| p.update_custom_value! @cdefs[d], "REALYOLD-#{d}" }
      es = p.create_snapshot @u
      es.update_attributes(created_at:1.year.ago)
      diffs.each {|d| p.update_custom_value! @cdefs[d], "OLD-#{d}" }
      es = p.create_snapshot @u
      es.update_attributes(created_at:3.days.ago)
      diffs.each {|d| p.update_custom_value! @cdefs[d], "AFTERAPPROVAL-#{d}" }
      es = p.create_snapshot @u
      es.update_attributes(created_at:1.days.ago)
      diffs.each {|d| p.update_custom_value! @cdefs[d], "NEW-#{d}" }
      arrays = @rc.to_arrays @u
      expect(arrays.size).to eq(2)
      expect(arrays[1][2]).to eq("OLD-origin")
      expect(arrays[1][3]).to eq("NEW-origin")
    end
    it "should write headings" do
      p = make_eligible_product
      expected = [ModelField.find_by_uid(:prod_uid).label, ModelField.find_by_uid(:class_cntry_iso).label]
      OpenChain::CustomHandler::AnnInc::AnnSapProductHandler::SAP_REVISED_PRODUCT_FIELDS.each do |d|
        expected << "Old #{@cdefs[d].model_field.label}"
        expected << "New #{@cdefs[d].model_field.label}"
      end
      expect(@rc.to_arrays(@u).first).to eq(expected)
    end
  end
end
