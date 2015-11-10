require 'spec_helper'

describe Product do
  describe :classifications_by_region do
    before :each do
      @product = Product.new
    end
    it "should include all classifications even if they are not in a region" do
      region = Factory(:region)
      
      country_in_region = Factory(:country)
      region.countries << country_in_region
      country_not_in_region = Factory(:country)
      
      classification_in_region = @product.classifications.build
      classification_in_region.country = country_in_region

      classification_not_in_region = @product.classifications.build
      classification_not_in_region.country = country_not_in_region

      expected = {nil => [classification_not_in_region], region => [classification_in_region]}

      expect(@product.classifications_by_region).to eq expected

    end
    it "should work with no regions" do
      country_1 = Factory(:country)
      country_2 = Factory(:country)

      expected_array = [country_1,country_2].collect do |cntry| 
        cls = @product.classifications.build
        cls.country = cntry
        cls
      end

      expected = {nil => expected_array}

      expect(@product.classifications_by_region).to eq expected
    end
    it "should include classifications multiple times if they are in multiple regions" do
      region_1 = Factory(:region)
      region_2 = Factory(:region)

      country = Factory(:country)

      [region_1,region_2].each {|r| r.countries << country}

      cls = @product.classifications.build
      cls.country = country

      expected = {nil => [], region_1=>[cls], region_2=>[cls]}

      expect(@product.classifications_by_region).to eq expected
    end
    it "should include regions with no classifications" do
      region_1 = Factory(:region)
      empty_region = Factory(:region)

      country = Factory(:country)

      region_1.countries << country

      cls = @product.classifications.build
      cls.country = country

      expected = {nil => [], region_1=>[cls], empty_region=>[]}

      expect(@product.classifications_by_region).to eq expected
    end
  end

  describe :wto6_changed_after? do
    before :each do
      @u = Factory(:user)
      @tr = Factory(:tariff_record,hts_1:'1234567890',hts_2:'9876543210',hts_3:'5555550000')
      @p = @tr.product
      @snapshot = @p.create_snapshot(@u)
      @snapshot.update_attributes(created_at:1.month.ago)
    end
    it "should return true if first 6 changed" do
      @tr.update_attributes(hts_1:'6666660000')
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_true
    end
    it "should return true if record added with new wto6" do
      tr = Factory(:tariff_record,hts_1:'6666660000',classification:Factory(:classification,product:@p))
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_true
    end
    it "should return false if record added with same wto6" do
      tr = Factory(:tariff_record,hts_1:'1234560000',classification:Factory(:classification,product:@p))
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_false
    end
    it "should return false if no history before date" do
      expect(@p.wto6_changed_after?(1.year.ago)).to be_false
    end
    it "should return false if record removed" do
      @tr.destroy
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_false
    end
    it "should return false if last 4 changed" do
      @tr.update_attributes(hts_1:'1234560000')
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_false
    end
    it "should return true if change happened in same day" do
      @snapshot.update_attributes(created_at:5.minutes.ago)
      tr = Factory(:tariff_record,hts_1:'6666660000',classification:Factory(:classification,product:@p))
      @p.reload
      expect(@p.wto6_changed_after?(3.minutes.ago)).to be_true
    end
  end
  describe :validate_tariff_numbers do
    it "should pass" do
      ot = Factory(:official_tariff)
      p = Product.new
      p.classifications.build(country:ot.country).tariff_records.build(hts_1:ot.hts_code)
      p.validate_tariff_numbers
      p.errors[:base].should be_empty
    end
    it "should pass if not tariffs for country in OfficialTariff" do
      c = Factory(:country)
      p = Product.new
      p.classifications.build(country:c).tariff_records.build(hts_1:'123')
      p.validate_tariff_numbers
      p.errors[:base].should be_empty
    end
    it "should fail if tariff doesn't exist" do
      ot = Factory(:official_tariff)
      p = Product.new
      p.classifications.build(country:ot.country).tariff_records.build(hts_1:"#{ot.hts_code}9")
      p.validate_tariff_numbers
      p.errors[:base].first.should == "Tariff number #{ot.hts_code}9 is invalid for #{ot.country.iso_code}"
    end
  end
  context "saved classifications exist" do
    before :each do
      @p = Factory(:product)
    end
    it "should return false for unsaved classification" do
      @p.classifications.build
      @p.saved_classifications_exist?.should be_false
    end
    it "should return true for mix" do
      Factory(:classification,:product=>@p)
      @p.classifications.build
      @p.saved_classifications_exist?.should be_true
    end
  end
  context "bill of materials" do
    describe :on_bill_of_materials? do
      context "true tests" do
        before :each do
          @parent = Factory(:product)
          @child = Factory(:product)
          @parent.bill_of_materials_children.create!(:child_product_id=>@child.id,:quantity=>3)
        end
        it "should be true if parent" do
          @parent.should be_on_bill_of_materials
        end
        it "should be true if child" do
          @child.should be_on_bill_of_materials
        end
      end
      it "should be false if not parent or child" do
        Factory(:product).should_not be_on_bill_of_materials
      end
    end
  end
  context "security" do
    before :each do
      MasterSetup.get.update_attributes(:variant_enabled=>true)
      @master_user = Factory(:master_user,:product_view=>true,:product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true,:variant_edit=>true)
      @importer_user = Factory(:importer_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true,:variant_edit=>true)
        @other_importer_user = Factory(:importer_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true,:variant_edit=>true)
      @linked_importer_user = Factory(:importer_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true,:variant_edit=>true)
      @importer_user.company.linked_companies << @linked_importer_user.company
      @unassociated_product = Factory(:product)
      @importer_product = Factory(:product,:importer=>@importer_user.company)
      @linked_product = Factory(:product,:importer=>@linked_importer_user.company)
    end
    describe "item permissions" do
      it "should allow master company to handle any product" do
        [@unassociated_product,@importer_product,@linked_product].each do |p|
          p.can_view?(@master_user).should be_true
          p.can_edit?(@master_user).should be_true
          p.can_classify?(@master_user).should be_true
          p.can_comment?(@master_user).should be_true
          p.can_attach?(@master_user).should be_true
          p.can_manage_variants?(@master_user).should be_true
        end
      end
      it "should allow importer to handle own products" do
        @importer_product.can_view?(@importer_user).should be_true
        @importer_product.can_edit?(@importer_user).should be_true
        @importer_product.can_classify?(@importer_user).should be_true
        @importer_product.can_comment?(@importer_user).should be_true
        @importer_product.can_attach?(@importer_user).should be_true
        @importer_product.can_manage_variants?(@importer_user).should be_true
      end
      it "should allow importer to handle linked company products" do
        @linked_product.can_view?(@importer_user).should be_true
        @linked_product.can_edit?(@importer_user).should be_true
        @linked_product.can_classify?(@importer_user).should be_true
        @linked_product.can_comment?(@importer_user).should be_true
        @linked_product.can_attach?(@importer_user).should be_true
        @linked_product.can_manage_variants?(@importer_user).should be_true
      end
      it "should not allow importer to handle unlinked company products" do
        @importer_product.can_view?(@other_importer_user).should be_false
        @importer_product.can_edit?(@other_importer_user).should be_false
        @importer_product.can_classify?(@other_importer_user).should be_false
        @importer_product.can_comment?(@other_importer_user).should be_false
        @importer_product.can_attach?(@other_importer_user).should be_false
        @importer_product.can_manage_variants?(@other_importer_user).should be_false
      end
      it "should not allow importer to handle product with no importer" do
        @unassociated_product.can_view?(@importer_user).should be_false
        @unassociated_product.can_edit?(@importer_user).should be_false
        @unassociated_product.can_classify?(@importer_user).should be_false
        @unassociated_product.can_comment?(@importer_user).should be_false
        @unassociated_product.can_attach?(@importer_user).should be_false
        @unassociated_product.can_manage_variants?(@importer_user).should be_false
      end
      context "vendor" do
        before :each do
          @vendor_user = Factory(:vendor_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true,:variant_edit=>true)
          @vendor_user.company.linked_companies << @linked_importer_user.company 
          @vendor_product = Factory(:product,:vendor=>@vendor_user.company) 
          @linked_vendor_user = Factory(:vendor_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true,:variant_edit=>true) 
          @linked_vendor_user.company.linked_companies << @vendor_user.company
        end

        it "should allow a vendor to handle own products" do
          @vendor_product.can_view?(@vendor_user).should be_true
          #Vendors can't edit products - only master and importer types
          @vendor_product.can_edit?(@vendor_user).should be_false
          @vendor_product.can_classify?(@vendor_user).should be_false
          @vendor_product.can_comment?(@vendor_user).should be_true
          @vendor_product.can_attach?(@vendor_user).should be_true
          @vendor_product.can_manage_variants?(@vendor_user).should be_false
        end

        it "should allow vendor to handle linked importer company products" do
          @linked_product.can_view?(@vendor_user).should be_true
          @linked_product.can_edit?(@vendor_user).should be_false
          @linked_product.can_classify?(@vendor_user).should be_false
          @linked_product.can_comment?(@vendor_user).should be_true
          @linked_product.can_attach?(@vendor_user).should be_true
          @linked_product.can_manage_variants?(@vendor_user).should be_false
        end
        
        it "should allow vendor to handle linked vendor company products" do
          @vendor_product.can_view?(@linked_vendor_user).should be_true
          @vendor_product.can_edit?(@linked_vendor_user).should be_false
          @vendor_product.can_classify?(@linked_vendor_user).should be_false
          @vendor_product.can_comment?(@linked_vendor_user).should be_true
          @vendor_product.can_attach?(@linked_vendor_user).should be_true
          @vendor_product.can_manage_variants?(@linked_vendor_user).should be_false
        end

        it "should not allow vendor to handle unlinked company products" do
          @importer_product.can_view?(@vendor_user).should be_false
          @importer_product.can_edit?(@vendor_user).should be_false
          @importer_product.can_classify?(@vendor_user).should be_false
          @importer_product.can_comment?(@vendor_user).should be_false
          @importer_product.can_attach?(@other_importer_user).should be_false
          @importer_product.can_manage_variants?(@vendor_user).should be_false
        end

        it "should not allow vendor to handle product with no vendor" do
          @unassociated_product.can_view?(@vendor_user).should be_false
          @unassociated_product.can_edit?(@vendor_user).should be_false
          @unassociated_product.can_classify?(@vendor_user).should be_false
          @unassociated_product.can_comment?(@vendor_user).should be_false
          @unassociated_product.can_attach?(@vendor_user).should be_false
          @unassociated_product.can_manage_variants?(@vendor_user).should be_false
        end
      end
    end
    describe "search_secure" do
      it "should find all for master" do
        Product.search_secure(@master_user, Product.where("1=1")).sort {|a,b| a.id<=>b.id}.should == [@linked_product,@importer_product,@unassociated_product].sort {|a,b| a.id<=>b.id}
      end
      it "should find importer's products" do
        Product.search_secure(@importer_user, Product.where("1=1")).sort {|a,b| a.id<=>b.id}.should == [@linked_product,@importer_product].sort {|a,b| a.id<=>b.id}
      end
      it "should not find other importer's products" do
        Product.search_secure(@other_importer_user,Product.where("1=1")).should be_empty
      end
    end
  end
  describe 'linkable attachments' do
    
    it 'should have linkable attachments' do
      product = Factory(:product)
      linkable = Factory(:linkable_attachment,:model_field_uid=>'prod',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>product)
      product.reload
      product.linkable_attachments.first.should == linkable
    end
  end

  describe "missing_classification_country?" do
    it "should reject making classification records without a country of some sort" do
      p = Factory(:product)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:decimal)

      params = {
        'id' => p.id,
        'prod_uid' => "unique_identifier123",
        'classifications_attributes' => [
          {@class_cd.model_field_uid.to_s => 'testing'}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_true
      p.reload
      expect(p.unique_identifier).to eq "unique_identifier123"
      expect(p.classifications.size).to eq 0
    end

    it "should not reject if updating an existing classification" do
      c = Factory(:classification)
      p = c.product
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:string)

      params = {
        'prod_uid' => "unique_identifier123",
        'classifications_attributes' => [
          {'id' => c.id, @class_cd.model_field_uid.to_s => 'testing'}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_true
      p.reload
      expect(p.unique_identifier).to eq "unique_identifier123"
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq "testing"
    end

    it "should allow creating classification if country id used" do
      country = Factory(:country)
      p = Factory(:product)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:string)

      params = {
        'classifications_attributes' => [
          {'class_cntry_id' => country.id}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_true
      p.reload
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.country).to eq country
    end

    it "should allow creating classification if country iso used" do
      country = Factory(:country)
      p = Factory(:product)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:string)

      params = {
        'classifications_attributes' => [
          {'class_cntry_iso' => country.iso_code}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_true
      p.reload
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.country).to eq country
    end

    it "should allow creating classification if country name used" do
      country = Factory(:country)
      p = Factory(:product)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:string)

      params = {
        'classifications_attributes' => [
          {'class_cntry_name' => country.name}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_true
      p.reload
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.country).to eq country
    end
  end
end
