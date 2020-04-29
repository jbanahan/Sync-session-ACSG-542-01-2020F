describe OpenChain::CustomHandler::AnnInc::AnnRelatedStylesManager do
  # Even though you should only call the static get_style method,
  # we're going to test the instance methods individually for ease of constructing
  # the test cases

  before :all do
    described_class.prep_custom_definitions (described_class::AGGREGATE_FIELDS+[:related_styles, :ac_date, :approved_date])
  end

  after :all do
    CustomDefinition.where('1=1').destroy_all
  end

  describe "get_style" do
    it "should not return read only style" do
      p = Factory(:product, unique_identifier:'base-u')
      found = described_class.get_style(base_style: 'base-u', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
      expect {found.update_attributes(name:'x')}.not_to raise_error
    end
  end
  describe "find_all_styles" do
    it "should find the base style" do
      p = Factory(:product, unique_identifier:'base-u')
      found = described_class.new(base_style: 'base-u', missy: nil, petite: nil, tall: nil, short: nil, plus: nil).find_all_styles
      expect(found).to eq([p])
    end
    it "should find the base style in the related styles field" do
      p = Factory(:product)
      c = described_class.new(base_style: 'base-u', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
      p.update_custom_value! c.related_cd, "x\nbase-u\ny"
      found = c.find_all_styles
      expect(found).to eq([p])
    end
    it "should find a related style in the unique_identifier field" do
      p = Factory(:product, unique_identifier:'other-u')
      found = described_class.new(base_style: 'base-u', missy: 'other-u', petite: nil, tall: nil, short: nil, plus: nil).find_all_styles
      expect(found).to eq([p])
    end
    it "should find a related style in the related styles field" do
      p = Factory(:product)
      c = described_class.new(base_style: 'base-u', missy: nil, petite: 'other-u', tall: nil, short: nil, plus: nil)
      p.update_custom_value! c.related_cd, "x\nother-u\ny"
      found = c.find_all_styles
      expect(found).to eq([p])
    end
    it "should find multipe related style and base style" do
      p = Factory(:product)
      c = described_class.new(base_style: 'base-u', missy: nil, petite: 'other-u', tall: 'tall-u', short: 'short-u', plus: 'plus-u')
      p.update_custom_value! c.related_cd, "x\nother-u\ny"
      p2 = Factory(:product, unique_identifier:'tall-u')
      p3 = Factory(:product)
      p3.update_custom_value! c.related_cd, "x\nbase-u\ny"
      dont_find = Factory(:product)
      found = c.find_all_styles
      expect(found).to match_array([p, p2, p3])
    end
  end

  describe "missy_style" do
    it "should return nil if it doesn't know" do
      expect(described_class.new(base_style: 'base', missy: nil, petite: 'pet', tall: nil, short: nil, plus: nil).missy_style).to be_nil
    end
    it "should return missy style if passed in" do
      expect(described_class.new(base_style: 'base', missy: 'mss', petite: nil, tall: nil, short: nil, plus: nil).missy_style).to eq('mss')
    end
    it "should return base style if tall, petite & short are set" do
      expect(described_class.new(base_style: 'base', missy: nil, petite: 'p', tall: 't', short: 's', plus: 'pl').missy_style).to eq('base')
    end
  end

  describe "product_to_use" do
    context "one database match" do
      it "should return matched product" do
        p = Factory(:product)
        c = described_class.new(base_style: 'base', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
        expect(c.product_to_use([p])).to eq(p)
      end
      it "should set missy style if it exists in record" do
        p = Factory(:product)
        c = described_class.new(base_style: 'base', missy: 'm-uid', petite: nil, tall: nil, short: nil, plus: nil)
        expect(c.product_to_use([p])).to eq(p)
      end
    end
    context "no database matches" do
      it "should return new product with missy uid if missy exists in record" do
        c = described_class.new(base_style: 'base', missy: 'm-uid', petite: nil, tall: nil, short: nil, plus: nil)
        p = c.product_to_use []
        expect(p.id).to be > 0 # should be saved in database
        expect(p.unique_identifier).to eq('m-uid')
        expect(p.get_custom_value(c.related_cd).value).to eq('base')
      end
      it "should return new product with base set if no missy in record" do
        c = described_class.new(base_style: 'base', missy: nil, petite: 'p-uid', tall: nil, short: nil, plus: nil)
        p = c.product_to_use []
        expect(p.id).to be > 0 # should be saved in database
        expect(p.unique_identifier).to eq('base')
        expect(p.get_custom_value(c.related_cd).value).to eq('p-uid')
      end
    end
    context "multiple database matches" do
      it "should use style with uid = missy if they both exist" do
        p = Factory(:product, unique_identifier:'m-uid')
        p2 = Factory(:product)
        c = described_class.new(base_style: 'base', missy: 'm-uid', petite: nil, tall: nil, short: nil, plus: nil)
        expect(c.product_to_use([p, p2])).to eq(p)
      end
      it "should use first style if no uid==missy" do
        p = Factory(:product)
        p2 = Factory(:product)
        c = described_class.new(base_style: 'base', missy: 'm-uid', petite: nil, tall: nil, short: nil, plus: nil)
        expect(c.product_to_use([p, p2])).to eq(p)
      end
      it "should use first style if no missy" do
        p = Factory(:product)
        p2 = Factory(:product, unique_identifier:'base')
        c = described_class.new(base_style: 'base', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
        expect(c.product_to_use([p, p2])).to eq(p)
      end
      it "should destroy other products" do
        p = Factory(:product, unique_identifier:'m-uid')
        p2 = Factory(:product)
        c = described_class.new(base_style: 'base', missy: 'm-uid', petite: nil, tall: nil, short: nil, plus: nil)
        expect(c.product_to_use([p, p2])).to eq(p)
        expect(Product.find_by_id(p2.id)).to be_nil
      end
      it "should merge_aggregate_values, set ac date, set classifications" do
        p = Factory(:product)
        p2 = Factory(:product, unique_identifier:'base')
        c = described_class.new(base_style: 'base', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
        a = [p, p2]
        expect(c).to receive(:merge_aggregate_values).with(p, a)
        expect(c).to receive(:set_earliest_ac_date).with(p, a)
        expect(c).to receive(:set_best_classifications)
        expect(c.product_to_use(a)).to eq(p)
      end
    end
  end

  describe "set_best_classifications" do
    before :each do
      @country = Factory(:country, import_location:true)
      @c = described_class.new(base_style: 'base', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
      @appr = @c.approved_cd
    end
    it "should raise exception if tariffs are not the same" do
      tr1 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr1.classification.update_custom_value! @appr, 1.day.ago
      tr2 = Factory(:tariff_record, hts_1:'1234567891', classification:Factory(:classification, country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      expect {@c.set_best_classifications tr1.product, [tr1.product, tr2.product]}.to raise_error /Cannot merge classifications with different tariffs/
    end
    it "should not raise exception for different tariff if not approved" do
      tr1 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr1.classification.update_custom_value! @appr, 1.day.ago
      tr2 = Factory(:tariff_record, hts_1:'1234567891', classification:Factory(:classification, country:@country))
      tr3 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr3.classification.update_custom_value! @appr, 1.day.ago
      expect {@c.set_best_classifications tr1.product, [tr1.product, tr2.product, tr3.product]}.not_to raise_error
    end
    it "should use the most recent approval date" do
      tr1 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr1.classification.update_custom_value! @appr, 2.day.ago
      tr2 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      @c.set_best_classifications tr1.product, [tr1.product, tr2.product]
      p = Product.find tr1.product.id
      expect(p.classifications.size).to eq(1)
      expect(p.classifications.first.get_custom_value(@appr).value.strftime("%Y%m%d")).to eq(1.day.ago.strftime("%Y%m%d"))
    end
    it "should give preference to existing linked product" do
      tr1 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr1.classification.update_custom_value! @appr, 1.day.ago
      tr2 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      @c.set_best_classifications tr1.product, [tr1.product, tr2.product]
      p = Product.find tr1.product.id
      expect(p.classifications.size).to eq(1)
      expect(p.classifications.first.id).to eq(tr1.classification.id)
    end
    it "should use most recently updated" do
      tr1 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr1.classification.update_custom_value! @appr, 2.day.ago
      tr2 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      tr3 = Factory(:tariff_record, hts_1:'1234567890', classification:Factory(:classification, country:@country))
      tr3.classification.update_custom_value! @appr, 1.day.ago
      tr3.classification.update_column :updated_at, 2.days.ago
      @c.set_best_classifications tr1.product, [tr1.product, tr2.product, tr3.product]
      p = Product.find tr1.product.id
      expect(p.classifications.size).to eq(1)
      expect(p.classifications.first.get_custom_value(@appr).value.strftime("%Y%m%d")).to eq(1.day.ago.strftime("%Y%m%d"))
      expect(p.classifications.first.id).to eq(tr2.classification.id)
    end
  end

  describe "merge_aggregate_values" do
    it "should include all values" do
      c = described_class.new(base_style: 'base', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
      po_cd = c.aggregate_defs[:po]
      p = Factory(:product)
      p.update_custom_value! po_cd, "p1\np3"
      p2 = Factory(:product)
      p2.update_custom_value! po_cd, "p2\np4"
      c.merge_aggregate_values p, [p, p2]
      found = Product.find p.id
      expect(found.get_custom_value(po_cd).value).to eq("p1\np2\np3\np4")
    end
  end

  describe "set_earliest_ac_date" do
    it "should set earliest ac date ignoring nulls" do
      c = described_class.new(base_style: 'base', missy: nil, petite: nil, tall: nil, short: nil, plus: nil)
      cd = c.ac_date_cd
      p = Factory(:product)
      p.update_custom_value! cd, 1.hour.ago
      p2 = Factory(:product)
      p3 = Factory(:product)
      p3.update_custom_value! cd, 1.year.ago

      c.set_earliest_ac_date p, [p, p3, p2]
      expect(Product.find(p.id).get_custom_value(cd).value.strftime("%Y%m%d")).to eq(p3.get_custom_value(cd).value.strftime("%Y%m%d"))
    end
  end

  describe "related_styles_value" do
    it "should return all related styles except missy when missy can be determined" do
      expect(described_class.new(base_style: 'b', missy: 'm', petite: 'p', tall: nil, short: nil, plus: nil).related_styles_value).to eq("b\np")
      expect(described_class.new(base_style: 'b', missy: nil, petite: 'p', tall: 't', short: 's', plus: 'pl').related_styles_value).to eq("p\nt\ns\npl")
    end
    it "should return all related styles except base when missy cannot be determined" do
      expect(described_class.new(base_style: 'b', missy: nil, petite: 'p', tall: nil, short: 's', plus: 'pl').related_styles_value).to eq("p\ns\npl")
      expect(described_class.new(base_style: 'b', missy: nil, petite: nil, tall: 't', short: 's', plus: 'pl').related_styles_value).to eq("t\ns\npl")
    end
  end

end
