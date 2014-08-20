require 'spec_helper'

describe OpenChain::CustomHandler::AnnInc::AnnRelatedStylesManager do
  #Even though you should only call the static get_style method,
  #we're going to test the instance methods individually for ease of constructing
  #the test cases

  before :all do
    described_class.prep_custom_definitions (described_class::AGGREGATE_FIELDS+[:related_styles,:ac_date,:approved_date])
  end

  after :all do
    CustomDefinition.where('1=1').destroy_all
  end

  describe :get_style do
    it "should not return read only style" do
      p = Factory(:product,unique_identifier:'base-u')
      found = described_class.get_style('base-u',nil,nil,nil)
      lambda {found.update_attributes(name:'x')}.should_not raise_error ActiveRecord::ReadOnlyRecord
    end
  end
  describe :find_all_styles do
    it "should find the base style" do
      p = Factory(:product,unique_identifier:'base-u')
      found = described_class.new('base-u',nil,nil,nil).find_all_styles
      found.should == [p]
    end
    it "should find the base style in the related styles field" do
      p = Factory(:product)
      c = described_class.new('base-u',nil,nil,nil)
      p.update_custom_value! c.related_cd, "x\nbase-u\ny"
      found = c.find_all_styles
      found.should == [p]
    end
    it "should find a related style in the unique_identifier field" do
      p = Factory(:product,unique_identifier:'other-u')
      found = described_class.new('base-u','other-u',nil,nil).find_all_styles
      found.should == [p]
    end
    it "should find a related style in the related styles field" do
      p = Factory(:product)
      c = described_class.new('base-u',nil,'other-u',nil)
      p.update_custom_value! c.related_cd, "x\nother-u\ny"
      found = c.find_all_styles
      found.should == [p]
    end
    it "should find multipe related style and base style" do
      p = Factory(:product)
      c = described_class.new('base-u',nil,'other-u','tall-u')
      p.update_custom_value! c.related_cd, "x\nother-u\ny"
      p2 = Factory(:product,unique_identifier:'tall-u')
      p3 = Factory(:product)
      p3.update_custom_value! c.related_cd, "x\nbase-u\ny"
      dont_find = Factory(:product)
      found = c.find_all_styles
      found.should =~ [p,p2,p3]
    end
  end

  describe :missy_style do
    it "should return nil if it doesn't know" do
      described_class.new('base',nil,'pet',nil).missy_style.should be_nil
    end
    it "should return missy style if passed in" do
      described_class.new('base','mss',nil,nil).missy_style.should == 'mss'
    end
    it "should return base style if tall & petite are set" do
      described_class.new('base',nil,'p','t').missy_style.should == 'base'
    end
  end

  describe :product_to_use do
    context "one database match" do
      it "should return matched product" do
        p = Factory(:product)
        c = described_class.new('base',nil,nil,nil)
        c.product_to_use([p]).should == p
      end
      it "should set missy style if it exists in record" do
        p = Factory(:product)
        c = described_class.new('base','m-uid',nil,nil)
        c.product_to_use([p]).should == p
      end
    end
    context "no database matches" do
      it "should return new product with missy uid if missy exists in record" do
        c = described_class.new('base','m-uid',nil,nil)
        p = c.product_to_use []
        p.id.should > 0 #should be saved in database
        p.unique_identifier.should == 'm-uid'
        p.get_custom_value(c.related_cd).value.should == 'base'
      end
      it "should return new product with base set if no missy in record" do
        c = described_class.new('base',nil,'p-uid',nil)
        p = c.product_to_use []
        p.id.should > 0 #should be saved in database
        p.unique_identifier.should == 'base'
        p.get_custom_value(c.related_cd).value.should == 'p-uid'
      end
    end
    context "multiple database matches" do
      it "should use style with uid = missy if they both exist" do
        p = Factory(:product,unique_identifier:'m-uid')
        p2 = Factory(:product)
        c = described_class.new('base','m-uid',nil,nil)
        c.product_to_use([p,p2]).should == p
      end
      it "should use first style if no uid==missy" do
        p = Factory(:product)
        p2 = Factory(:product)
        c = described_class.new('base','m-uid',nil,nil)
        c.product_to_use([p,p2]).should == p
      end
      it "should use first style if no missy" do
        p = Factory(:product)
        p2 = Factory(:product,unique_identifier:'base')
        c = described_class.new('base',nil,nil,nil)
        c.product_to_use([p,p2]).should == p
      end
      it "should destroy other products" do
        p = Factory(:product,unique_identifier:'m-uid')
        p2 = Factory(:product)
        c = described_class.new('base','m-uid',nil,nil)
        c.product_to_use([p,p2]).should == p
        Product.find_by_id(p2.id).should be_nil
      end
      it "should merge_aggregate_values, set ac date, set classifications" do
        p = Factory(:product)
        p2 = Factory(:product,unique_identifier:'base')
        c = described_class.new('base',nil,nil,nil)
        a = [p,p2]
        c.should_receive(:merge_aggregate_values).with(p,a)
        c.should_receive(:set_earliest_ac_date).with(p,a)
        c.should_receive(:set_best_classifications)
        c.product_to_use(a).should == p
      end
    end
  end

  describe :set_best_classifications do 
    before :each do
      @country = Factory(:country,import_location:true)
      @c = described_class.new('base',nil,nil,nil)
      @appr = @c.approved_cd
    end
    it "should raise exception if tariffs are not the same" do
      tr1 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr1.classification.update_custom_value! @appr, 1.day.ago
      tr2 = Factory(:tariff_record,hts_1:'1234567891',classification:Factory(:classification,country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      lambda {@c.set_best_classifications tr1.product, [tr1.product,tr2.product]}.should raise_error /Cannot merge classifications with different tariffs/
    end
    it "should not raise exception for different tariff if not approved" do
      tr1 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr1.classification.update_custom_value! @appr, 1.day.ago
      tr2 = Factory(:tariff_record,hts_1:'1234567891',classification:Factory(:classification,country:@country))
      tr3 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr3.classification.update_custom_value! @appr, 1.day.ago
      lambda {@c.set_best_classifications tr1.product, [tr1.product,tr2.product,tr3.product]}.should_not raise_error /Cannot merge classifications with different tariffs/
    end
    it "should use the most recent approval date" do
      tr1 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr1.classification.update_custom_value! @appr, 2.day.ago
      tr2 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      @c.set_best_classifications tr1.product, [tr1.product,tr2.product]
      p = Product.find tr1.product.id
      p.should have(1).classifications
      p.classifications.first.get_custom_value(@appr).value.strftime("%Y%m%d").should == 1.day.ago.strftime("%Y%m%d")
    end
    it "should give preference to existing linked product" do
      tr1 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr1.classification.update_custom_value! @appr, 1.day.ago
      tr2 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      @c.set_best_classifications tr1.product, [tr1.product,tr2.product]
      p = Product.find tr1.product.id
      p.should have(1).classifications
      p.classifications.first.id.should == tr1.classification.id
    end
    it "should use most recently updated" do
      tr1 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr1.classification.update_custom_value! @appr, 2.day.ago
      tr2 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr2.classification.update_custom_value! @appr, 1.day.ago
      tr3 = Factory(:tariff_record,hts_1:'1234567890',classification:Factory(:classification,country:@country))
      tr3.classification.update_custom_value! @appr, 1.day.ago
      tr3.classification.update_attributes(updated_at:2.days.ago)
      @c.set_best_classifications tr1.product, [tr1.product,tr2.product,tr3.product]
      p = Product.find tr1.product.id
      p.should have(1).classifications
      p.classifications.first.get_custom_value(@appr).value.strftime("%Y%m%d").should == 1.day.ago.strftime("%Y%m%d")
      p.classifications.first.id.should == tr2.classification.id
    end
  end

  describe :merge_aggregate_values do
    it "should include all values" do
      c = described_class.new('base',nil,nil,nil)
      po_cd = c.aggregate_defs[:po]
      p = Factory(:product)
      p.update_custom_value! po_cd, "p1\np3"
      p2 = Factory(:product)
      p2.update_custom_value! po_cd, "p2\np4"
      c.merge_aggregate_values p, [p,p2]
      found = Product.find p.id
      found.get_custom_value(po_cd).value.should == "p1\np2\np3\np4"
    end
  end

  describe :set_earliest_ac_date do
    it "should set earliest ac date ignoring nulls" do
      c = described_class.new('base',nil,nil,nil)
      cd = c.ac_date_cd
      p = Factory(:product)
      p.update_custom_value! cd, 1.hour.ago
      p2 = Factory(:product)
      p3 = Factory(:product)
      p3.update_custom_value! cd, 1.year.ago

      c.set_earliest_ac_date p, [p,p3,p2]
      Product.find(p.id).get_custom_value(cd).value.strftime("%Y%m%d").should == p3.get_custom_value(cd).value.strftime("%Y%m%d")
    end
  end

  describe :related_styles_value do
    it "should return all related styles except missy when missy can be determined" do
      described_class.new('b','m','p',nil).related_styles_value.should == "b\np"
      described_class.new('b',nil,'p','t').related_styles_value.should == "p\nt"
    end
    it "should return all related styles except base when missy cannot be determined" do
      described_class.new('b',nil,'p',nil).related_styles_value.should == 'p'
      described_class.new('b',nil,nil,'t').related_styles_value.should == 't'
    end
  end

end
