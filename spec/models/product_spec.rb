describe Product do
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  describe "product_importer" do
    let(:imp) { create(:company, system_code: "ACME")}
    let(:entry) { create(:entry, importer: imp) }
    let!(:imp1) { create(:company, system_code: "NOTACME")}
    let(:rule_attr) {{}}

    it "returns the company associated with the entry with no importer system code specified" do
      expect(Product.product_importer(entry, rule_attr["importer_system_code"])).to eq imp
    end

    it "returns the company given the system code in the rule attribute" do
      rule_attr = {"importer_system_code"=>"NOTACME"}
      expect(Product.product_importer(entry, rule_attr["importer_system_code"])).to eq imp1
    end
  end

  describe "create_prod_part_hsh" do
    before do
      @cdefs ||= self.class.prep_custom_definitions [:prod_part_number]
    end
    let(:imp) { create(:company, system_code: "ACME") }
    let(:entry) { create(:entry, importer: imp) }
    let(:invoice_1) { create(:commercial_invoice, entry: entry, invoice_number: "123456")}
    let!(:line_1) { create(:commercial_invoice_line, commercial_invoice: invoice_1,
      line_number: 1, part_number: "attr_part_1") }
    let(:invoice_2) { create(:commercial_invoice, entry: entry, invoice_number: "654321") }
    let!(:line_2) { create(:commercial_invoice_line, commercial_invoice: invoice_2,
      line_number: 1, part_number: "attr_part_2") }
    let!(:line_2_2) { create(:commercial_invoice_line,
      commercial_invoice: invoice_2, line_number: 2, part_number: "attr_part_3") }

    let!(:product_1) { create(:product, importer: imp, unique_identifier: "attr_part_1")}
    let!(:product_2) { create(:product, importer: imp, unique_identifier: "attr_part_2")}
    let!(:product_3) { create(:product, importer: imp, unique_identifier: "attr_part_3")}

    let!(:cval_fw_1) { CustomValue.create! custom_definition: @cdefs[:prod_part_number], customizable: product_1, string_value: "attr_part_1" }
    let!(:cval_fw_2) { CustomValue.create! custom_definition: @cdefs[:prod_part_number], customizable: product_2, string_value: "attr_part_2" }
    let!(:cval_fw_3) { CustomValue.create! custom_definition: @cdefs[:prod_part_number], customizable: product_3, string_value: "attr_part_3" }

    context "vandegrift instance" do
      it "creates a hash of product part numbers" do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("WWW").and_return true

        line_data = entry.commercial_invoices
                         .flat_map(&:commercial_invoice_lines)
                         .map { |cil| {inv_num: cil.commercial_invoice.invoice_number,
                                      line_num: cil.line_number,
                                      part_num: cil.part_number} }
        expect(Product.create_prod_part_hsh(imp.id,
          line_data.map { |l| l[:part_num] }, @cdefs)).to include(
            product_1.id=>"attr_part_1",
            product_2.id=>"attr_part_2",
            product_3.id=>"attr_part_3")
      end
    end

    context "other instances" do
      it "creates a hash of product part numbers" do
        ms = stub_master_setup
        allow(ms).to receive(:custom_feature?).with("WWW").and_return false

        cdefs = double "cdefs"
        line_data = entry.commercial_invoices
                         .flat_map(&:commercial_invoice_lines)
                         .map { |cil| {inv_num: cil.commercial_invoice.invoice_number,
                                      line_num: cil.line_number,
                                      part_num: cil.part_number} }
        expect(Product.create_prod_part_hsh(imp.id,
          line_data.map { |l| l[:part_num] }, cdefs)).to include(
            product_1.id=>"attr_part_1",
            product_2.id=>"attr_part_2",
            product_3.id=>"attr_part_3")
      end
    end
  end

  describe "classifications_by_region" do
    before :each do
      @product = Product.new
    end
    it "should include all classifications even if they are not in a region" do
      region = create(:region)

      country_in_region = create(:country)
      region.countries << country_in_region
      country_not_in_region = create(:country)

      classification_in_region = @product.classifications.build
      classification_in_region.country = country_in_region

      classification_not_in_region = @product.classifications.build
      classification_not_in_region.country = country_not_in_region

      expected = {nil => [classification_not_in_region], region => [classification_in_region]}

      expect(@product.classifications_by_region).to eq expected

    end
    it "should work with no regions" do
      country_1 = create(:country)
      country_2 = create(:country)

      expected_array = [country_1, country_2].collect do |cntry|
        cls = @product.classifications.build
        cls.country = cntry
        cls
      end

      expected = {nil => expected_array}

      expect(@product.classifications_by_region).to eq expected
    end
    it "should include classifications multiple times if they are in multiple regions" do
      region_1 = create(:region)
      region_2 = create(:region)

      country = create(:country)

      [region_1, region_2].each {|r| r.countries << country}

      cls = @product.classifications.build
      cls.country = country

      expected = {nil => [], region_1=>[cls], region_2=>[cls]}

      expect(@product.classifications_by_region).to eq expected
    end
    it "should include regions with no classifications" do
      region_1 = create(:region)
      empty_region = create(:region)

      country = create(:country)

      region_1.countries << country

      cls = @product.classifications.build
      cls.country = country

      expected = {nil => [], region_1=>[cls], empty_region=>[]}

      expect(@product.classifications_by_region).to eq expected
    end
  end

  describe "wto6_changed_after?", :snapshot do
    before :each do
      @u = create(:user)
      @tr = create(:tariff_record, hts_1:'1234567890', hts_2:'9876543210', hts_3:'5555550000')
      @p = @tr.product
      @snapshot = @p.create_snapshot(@u)
      @snapshot.update!(created_at:1.month.ago)
    end
    it "should return true if first 6 changed" do
      @tr.update!(hts_1:'6666660000')
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_truthy
    end
    it "should return true if record added with new wto6" do
      create(:tariff_record, hts_1:'6666660000', classification:create(:classification, product:@p))
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_truthy
    end
    it "should return false if record added with same wto6" do
      create(:tariff_record, hts_1:'1234560000', classification:create(:classification, product:@p))
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_falsey
    end
    it "should return false if no history before date" do
      expect(@p.wto6_changed_after?(1.year.ago)).to be_falsey
    end
    it "should return false if record removed" do
      @tr.destroy
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_falsey
    end
    it "should return false if last 4 changed" do
      @tr.update!(hts_1:'1234560000')
      @p.reload
      expect(@p.wto6_changed_after?(1.day.ago)).to be_falsey
    end
    it "should return true if change happened in same day" do
      @snapshot.update!(created_at:5.minutes.ago)
      create(:tariff_record, hts_1:'6666660000', classification:create(:classification, product:@p))
      @p.reload
      expect(@p.wto6_changed_after?(3.minutes.ago)).to be_truthy
    end
  end
  describe "validate_tariff_numbers" do
    it "should pass" do
      ot = create(:official_tariff)
      p = Product.new
      p.classifications.build(country:ot.country).tariff_records.build(hts_1:ot.hts_code)
      p.validate_tariff_numbers
      expect(p.errors[:base]).to be_empty
    end
    it "should pass if not tariffs for country in OfficialTariff" do
      c = create(:country)
      p = Product.new
      p.classifications.build(country:c).tariff_records.build(hts_1:'123')
      p.validate_tariff_numbers
      expect(p.errors[:base]).to be_empty
    end
    it "should fail if tariff doesn't exist" do
      ot = create(:official_tariff)
      p = Product.new
      p.classifications.build(country:ot.country).tariff_records.build(hts_1:"#{ot.hts_code}9")
      p.validate_tariff_numbers
      expect(p.errors[:base].first).to eq("Tariff number #{ot.hts_code}9 is invalid for #{ot.country.iso_code}")
    end
  end
  context "saved classifications exist" do
    before :each do
      @p = create(:product)
    end
    it "should return false for unsaved classification" do
      @p.classifications.build
      expect(@p.saved_classifications_exist?).to be_falsey
    end
    it "should return true for mix" do
      create(:classification, :product=>@p)
      @p.classifications.build
      expect(@p.saved_classifications_exist?).to be_truthy
    end
  end
  context "bill of materials" do
    describe "on_bill_of_materials?" do
      context "true tests" do
        before :each do
          @parent = create(:product)
          @child = create(:product)
          @parent.bill_of_materials_children.create!(:child_product_id=>@child.id, :quantity=>3)
        end
        it "should be true if parent" do
          expect(@parent).to be_on_bill_of_materials
        end
        it "should be true if child" do
          expect(@child).to be_on_bill_of_materials
        end
      end
      it "should be false if not parent or child" do
        expect(create(:product)).not_to be_on_bill_of_materials
      end
    end
  end
  context "security" do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:variant_enabled).and_return true
      allow(ms).to receive(:classification_enabled).and_return true
      ms
    }

    before :each do
      @master_user = create(:master_user, :product_view=>true, :product_edit=>true, :classification_edit=>true, :product_comment=>true, :product_attach=>true, :variant_edit=>true)
      @importer_user = create(:importer_user, :product_view=>true, :product_edit=>true, :classification_edit=>true, :product_comment=>true, :product_attach=>true, :variant_edit=>true)
        @other_importer_user = create(:importer_user, :product_view=>true, :product_edit=>true, :classification_edit=>true, :product_comment=>true, :product_attach=>true, :variant_edit=>true)
      @linked_importer_user = create(:importer_user, :product_view=>true, :product_edit=>true, :classification_edit=>true, :product_comment=>true, :product_attach=>true, :variant_edit=>true)
      @importer_user.company.linked_companies << @linked_importer_user.company
      @unassociated_product = create(:product)
      @importer_product = create(:product, :importer=>@importer_user.company)
      @linked_product = create(:product, :importer=>@linked_importer_user.company)
    end
    describe "item permissions" do
      it "should allow master company to handle any product" do
        [@unassociated_product, @importer_product, @linked_product].each do |p|
          expect(p.can_view?(@master_user)).to be_truthy
          expect(p.can_edit?(@master_user)).to be_truthy
          expect(p.can_classify?(@master_user)).to be_truthy
          expect(p.can_comment?(@master_user)).to be_truthy
          expect(p.can_attach?(@master_user)).to be_truthy
          expect(p.can_manage_variants?(@master_user)).to be_truthy
        end
      end
      it "should allow importer to handle own products" do
        expect(@importer_product.can_view?(@importer_user)).to be_truthy
        expect(@importer_product.can_edit?(@importer_user)).to be_truthy
        expect(@importer_product.can_classify?(@importer_user)).to be_truthy
        expect(@importer_product.can_comment?(@importer_user)).to be_truthy
        expect(@importer_product.can_attach?(@importer_user)).to be_truthy
        expect(@importer_product.can_manage_variants?(@importer_user)).to be_truthy
      end
      it "should allow importer to handle linked company products" do
        expect(@linked_product.can_view?(@importer_user)).to be_truthy
        expect(@linked_product.can_edit?(@importer_user)).to be_truthy
        expect(@linked_product.can_classify?(@importer_user)).to be_truthy
        expect(@linked_product.can_comment?(@importer_user)).to be_truthy
        expect(@linked_product.can_attach?(@importer_user)).to be_truthy
        expect(@linked_product.can_manage_variants?(@importer_user)).to be_truthy
      end
      it "should not allow importer to handle unlinked company products" do
        expect(@importer_product.can_view?(@other_importer_user)).to be_falsey
        expect(@importer_product.can_edit?(@other_importer_user)).to be_falsey
        expect(@importer_product.can_classify?(@other_importer_user)).to be_falsey
        expect(@importer_product.can_comment?(@other_importer_user)).to be_falsey
        expect(@importer_product.can_attach?(@other_importer_user)).to be_falsey
        expect(@importer_product.can_manage_variants?(@other_importer_user)).to be_falsey
      end
      it "should not allow importer to handle product with no importer" do
        expect(@unassociated_product.can_view?(@importer_user)).to be_falsey
        expect(@unassociated_product.can_edit?(@importer_user)).to be_falsey
        expect(@unassociated_product.can_classify?(@importer_user)).to be_falsey
        expect(@unassociated_product.can_comment?(@importer_user)).to be_falsey
        expect(@unassociated_product.can_attach?(@importer_user)).to be_falsey
        expect(@unassociated_product.can_manage_variants?(@importer_user)).to be_falsey
      end
      context "vendor" do
        before :each do
          @vendor_user = create(:vendor_user, :product_view=>true, :product_edit=>true, :classification_edit=>true, :product_comment=>true, :product_attach=>true, :variant_edit=>true)
          @vendor_user.company.linked_companies << @linked_importer_user.company
          @vendor_product = create(:product)
          @vendor_product.vendors << @vendor_user.company
          @linked_vendor_user = create(:vendor_user, :product_view=>true, :product_edit=>true, :classification_edit=>true, :product_comment=>true, :product_attach=>true, :variant_edit=>true)
          @linked_vendor_user.company.linked_companies << @vendor_user.company
        end

        it "should allow a vendor to handle own products" do
          expect(@vendor_product.can_view?(@vendor_user)).to be_truthy
          # Vendors can't edit products - only master and importer types
          expect(@vendor_product.can_edit?(@vendor_user)).to be_falsey
          expect(@vendor_product.can_classify?(@vendor_user)).to be_falsey
          expect(@vendor_product.can_comment?(@vendor_user)).to be_truthy
          expect(@vendor_product.can_attach?(@vendor_user)).to be_truthy
          expect(@vendor_product.can_manage_variants?(@vendor_user)).to be_falsey
        end

        it "should allow vendor to handle linked importer company products" do
          expect(@linked_product.can_view?(@vendor_user)).to be_truthy
          expect(@linked_product.can_edit?(@vendor_user)).to be_falsey
          expect(@linked_product.can_classify?(@vendor_user)).to be_falsey
          expect(@linked_product.can_comment?(@vendor_user)).to be_truthy
          expect(@linked_product.can_attach?(@vendor_user)).to be_truthy
          expect(@linked_product.can_manage_variants?(@vendor_user)).to be_falsey
        end

        it "should allow vendor to handle linked vendor company products" do
          expect(@vendor_product.can_view?(@linked_vendor_user)).to be_truthy
          expect(@vendor_product.can_edit?(@linked_vendor_user)).to be_falsey
          expect(@vendor_product.can_classify?(@linked_vendor_user)).to be_falsey
          expect(@vendor_product.can_comment?(@linked_vendor_user)).to be_truthy
          expect(@vendor_product.can_attach?(@linked_vendor_user)).to be_truthy
          expect(@vendor_product.can_manage_variants?(@linked_vendor_user)).to be_falsey
        end

        it "should not allow vendor to handle unlinked company products" do
          expect(@importer_product.can_view?(@vendor_user)).to be_falsey
          expect(@importer_product.can_edit?(@vendor_user)).to be_falsey
          expect(@importer_product.can_classify?(@vendor_user)).to be_falsey
          expect(@importer_product.can_comment?(@vendor_user)).to be_falsey
          expect(@importer_product.can_attach?(@other_importer_user)).to be_falsey
          expect(@importer_product.can_manage_variants?(@vendor_user)).to be_falsey
        end

        it "should not allow vendor to handle product with no vendor" do
          expect(@unassociated_product.can_view?(@vendor_user)).to be_falsey
          expect(@unassociated_product.can_edit?(@vendor_user)).to be_falsey
          expect(@unassociated_product.can_classify?(@vendor_user)).to be_falsey
          expect(@unassociated_product.can_comment?(@vendor_user)).to be_falsey
          expect(@unassociated_product.can_attach?(@vendor_user)).to be_falsey
          expect(@unassociated_product.can_manage_variants?(@vendor_user)).to be_falsey
        end
      end
    end
    describe "search_secure" do
      it "should find all for master" do
        expect(Product.search_secure(@master_user, Product.where("1=1")).sort {|a, b| a.id<=>b.id}).to eq([@linked_product, @importer_product, @unassociated_product].sort {|a, b| a.id<=>b.id})
      end
      it "should find importer's products" do
        expect(Product.search_secure(@importer_user, Product.where("1=1")).sort {|a, b| a.id<=>b.id}).to eq([@linked_product, @importer_product].sort {|a, b| a.id<=>b.id})
      end
      it "should not find other importer's products" do
        expect(Product.search_secure(@other_importer_user, Product.where("1=1"))).to be_empty
      end
    end
  end
  describe 'linkable attachments' do

    it 'should have linkable attachments' do
      product = create(:product)
      linkable = create(:linkable_attachment, :model_field_uid=>'prod', :value=>'ordn')
      LinkedAttachment.create(:linkable_attachment_id=>linkable.id, :attachable=>product)
      product.reload
      expect(product.linkable_attachments.first).to eq(linkable)
    end
  end

  describe "missing_classification_country?" do
    it "should reject making classification records without a country of some sort" do
      p = create(:product)
      @class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:decimal)

      params = {
        'id' => p.id,
        'prod_uid' => "unique_identifier123",
        'classifications_attributes' => [
          {@class_cd.model_field_uid.to_s => 'testing'}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_truthy
      p.reload
      expect(p.unique_identifier).to eq "unique_identifier123"
      expect(p.classifications.size).to eq 0
    end

    it "should not reject if updating an existing classification" do
      c = create(:classification)
      p = c.product
      @class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)

      params = {
        'prod_uid' => "unique_identifier123",
        'classifications_attributes' => [
          {'id' => c.id, @class_cd.model_field_uid.to_s => 'testing'}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_truthy
      p.reload
      expect(p.unique_identifier).to eq "unique_identifier123"
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.get_custom_value(@class_cd).value).to eq "testing"
    end

    it "should allow creating classification if country id used" do
      country = create(:country)
      p = create(:product)
      @class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)

      params = {
        'classifications_attributes' => [
          {'class_cntry_id' => country.id}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_truthy
      p.reload
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.country).to eq country
    end

    it "should allow creating classification if country iso used" do
      country = create(:country)
      p = create(:product)
      @class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)

      params = {
        'classifications_attributes' => [
          {'class_cntry_iso' => country.iso_code}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_truthy
      p.reload
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.country).to eq country
    end

    it "should allow creating classification if country name used" do
      country = create(:country)
      p = create(:product)
      @class_cd = create(:custom_definition, :module_type=>'Classification', :data_type=>:string)

      params = {
        'classifications_attributes' => [
          {'class_cntry_name' => country.name}
        ]
      }

      expect(p.update_model_field_attributes! params).to be_truthy
      p.reload
      expect(p.classifications.size).to eq 1
      expect(p.classifications.first.country).to eq country
    end
  end

  describe "hts_for_country" do

    let (:product) {
      p = create(:product)
      c = create(:classification, product: p, country: create(:country, iso_code: "CA"))
      c.tariff_records.create! hts_1: "1234567890", hts_2: "987654321", hts_3: "12731289"
      c.tariff_records.create! hts_1: "1890231908"

      c = create(:classification, product: p, country: create(:country, iso_code: "US"))
      c.tariff_records.create! hts_1: "1289731280"

      p.reload
    }

    it "pulls the hts number for a specific country" do
      expect(product.hts_for_country("US")).to eq ["1289731280"]
    end

    it "allows passing country object" do
      expect(product.hts_for_country(Country.where(iso_code: "US").first)).to eq ["1289731280"]
    end

    it "returns all the hts values" do
      expect(product.hts_for_country("CA")).to eq ["1234567890", "1890231908"]
    end

    it "returns blank if no hts" do
      product
      us = Country.where(iso_code: "US").first
      c = product.classifications.find {|c| c.country_id == us.id}
      c.tariff_records.destroy_all

      expect(product.hts_for_country("US")).to eq []
    end

    it "raises an error if the country doesn't exist" do
      expect {product.hts_for_country("XX")}.to raise_error "No country record found for ISO Code 'XX'."
    end
  end

  describe "update_hts_for_country" do
    let (:product) {
      p = create(:product)
      c = create(:classification, product: p, country: create(:country, iso_code: "CA"))
      c.tariff_records.create! hts_1: "1234567890", hts_2: "987654321", hts_3: "12731289"
      c.tariff_records.create! hts_1: "1890231908"

      c = create(:classification, product: p, country: create(:country, iso_code: "US"))
      c.tariff_records.create! hts_1: "1289731280"

      p.reload
    }

    it "sets hts value into hts_1 of specified country" do
      product.update_hts_for_country "US", "987654321"

      expect(product.hts_for_country("US")).to eq ["987654321"]
    end

    it "sets multiple hts values into hts_1 of specified country" do
      product.update_hts_for_country "US", ["987654321", "1280123012"]

      expect(product.hts_for_country("US")).to eq ["987654321", "1280123012"]
    end

    it "updates multiple hts values" do
      product.update_hts_for_country "CA", ["987654321", "1280123012"]
      expect(product.hts_for_country("CA")).to eq ["987654321", "1280123012"]
    end
  end
end
