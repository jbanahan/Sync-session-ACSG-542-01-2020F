require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UaArticleMasterParser do
  before :all do
    # Speed up specs by preloading custom defs
    described_class.new.cdefs
  end

  after :all do
    # destory defs since before :all doesn't run in a transaction
    CustomDefinition.destroy_all
  end

  let(:doc) { REXML::Document.new(File.open "spec/fixtures/files/ua_article_master_parser.xml") }
  let(:cdefs) { subject.cdefs }
  let!(:ca) { Factory(:country, name: "Canada", iso_code: "CA") }

  def include_variants doc, ids
    (["1","2","3"] - ids).each { |id| doc.elements.delete("//UPC[@id='#{id}']") }
    doc.to_s
  end

  describe "integration_folder" do
    it "uses integration folder" do
      expect(described_class.integration_folder).to eq "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ua_article_master"
    end
  end

  describe "system_code" do
    it "uses UAPARTS if it's a custom feature" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("UAPARTS Staging").and_return true
      expect(subject.system_code).to eq "UAPARTS"
    end

    it "uses UNDAR by default" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("UAPARTS Staging").and_return false
      expect(subject.system_code).to eq "UNDAR"
    end
  end

  describe "parse" do
    let! (:ms) {
      ms = stub_master_setup
      allow(ms).to receive(:uuid).and_return "12345"
      allow(ms).to receive(:custom_feature?).with("UAPARTS Staging").and_return true
      ms
    }

    let(:user) { User.integration }
    let!(:imp) { Factory(:importer, name: "Under Armour", system_code: "UAPARTS")}

    context "with foreground processing" do
      before :each do
        allow(ms).to receive(:custom_feature?).with("UA Background Article Processing").and_return false
      end

      it "creates products, variants, tariff records from XML" do
        doc_string = include_variants(doc, ["1", "2"])

        expect_any_instance_of(Product).to receive(:create_snapshot).with(user,nil,"path")
        expect{ described_class.parse doc_string, key: "path" }.to change(Product, :count).from(0).to(1)
        expect(Classification.count).to eq 1
        expect(TariffRecord.count).to eq 1
        expect(Variant.count).to eq 2

        p = Product.first
        expect(p.get_custom_value(cdefs[:prod_prepack]).value).to be_falsey

        cl = p.classifications.first
        var_1 = p.variants[0]
        var_2 = p.variants[1]

        expect(p.unique_identifier).to eq "UAPARTS-art num"
        expect(p.custom_value cdefs[:prod_part_number]).to eq "art num"
        expect(p.name).to eq "art descr"
        expect(p.importer).to eq imp

        expect(cl.country).to eq ca
        expect(cl.tariff_records.first.hts_1).to eq "1111111111"
        expect(cl.custom_value(cdefs[:class_customs_description])).to eq "customs descr"
        expect(var_1.variant_identifier).to eq "sku 1"
        expect(var_1.custom_value(cdefs[:var_upc])).to eq "upc num 1"
        expect(var_1.custom_value(cdefs[:var_article_number])).to eq "var art 1"
        expect(var_1.custom_value(cdefs[:var_description])).to eq "var descr 1"
        expect(var_1.custom_value(cdefs[:var_hts_code])).to eq "1111111111"

        expect(var_2.variant_identifier).to eq "sku 2"
        expect(var_2.custom_value(cdefs[:var_upc])).to eq "upc num 2"
        expect(var_2.custom_value(cdefs[:var_article_number])).to eq "var art 2"
        expect(var_2.custom_value(cdefs[:var_description])).to eq "var descr 2"
        expect(var_2.custom_value(cdefs[:var_hts_code])).to eq "1111111111"
      end

      it "makes no updates if data unchanged" do
        doc_string = include_variants(doc, ["1"])
        expect_any_instance_of(Product).not_to receive(:create_snapshot) #purpose of the test

        p = Factory(:product, importer: imp, unique_identifier: "UAPARTS-art num", name: "art descr")
        cl = Factory(:classification, product: p, country: ca)
        cl.update_custom_value!(cdefs[:class_customs_description], "customs descr")
        Factory(:tariff_record, classification: cl, hts_1: "1111111111")
        var = Factory(:variant, product: p, variant_identifier: "sku 1")
        var.find_and_set_custom_value(cdefs[:var_upc], "upc num 1")
        var.find_and_set_custom_value(cdefs[:var_article_number], "var art 1")
        var.find_and_set_custom_value(cdefs[:var_description], "var descr 1")
        var.find_and_set_custom_value(cdefs[:var_hts_code], "1111111111")
        var.save!

        described_class.parse doc_string, key: "path"
      end
    end

    context "with background processing" do

      before :each do
        allow(ms).to receive(:custom_feature?).with("UA Background Article Processing").and_return true
      end

      it "delays processing of the styles if instructed" do
        allow(ms).to receive(:custom_feature?).with("UA Background Article Processing").and_return true
        expect(described_class).to receive(:delay).with(queue: "ua").and_return described_class
        xml = nil
        expect(described_class).to receive(:process_article) do |xml_string, filename|
          xml = xml_string
          expect(filename).to eq "path"
        end

        described_class.parse include_variants(doc, ["1", "2"]), key: "path"

        expect(xml).not_to be_nil
        # Make sure there's no newlines in the xml (.ie it's a compact output)
        expect(xml).not_to include "\n"
        doc = REXML::Document.new xml
        expect(doc.root.name).to eq "Style"
        expect(REXML::XPath.first(doc, "/Style/Article/ArticleNumber").try(:text)).to eq "art num"
      end
    end
    
  end

  context "instance methods" do
    before do
      ms = stub_master_setup
      allow(ms).to receive(:uuid).and_return "12345"
      allow(ms).to receive(:custom_feature?).with("UAPARTS Staging").and_return true
      ca
    end

    let(:prod) { Factory(:product, importer: imp)}
    let(:change_flag) { MutableBoolean.new(false) }
    let!(:imp) { Factory(:importer, name: "Under Armour", system_code: "UAPARTS")}

    describe "create_or_update_product!" do
      let(:art_elem) { double "art_elem" }

      context "when article number isn't nil" do
        before do
          expect(art_elem).to receive(:text).with("ArticleNumber").and_return "uid"
          expect(art_elem).to receive(:text).with("ArticleDescription").and_return "name"
        end

        it "updates product if it exists and has been changed" do
          prod = Factory(:product, unique_identifier: "UAPARTS-uid", name: nil, importer: imp)
          subject.create_or_update_product! art_elem, change_flag
          prod.reload
          expect(prod.name).to eq "name"
          expect(Product.count).to eq 1
          expect(change_flag.value).to eq true
        end

        it "doesn't update product if unchanged" do
          prod = Factory(:product, unique_identifier: "UAPARTS-uid", name: "name", importer: imp)
          subject.create_or_update_product! art_elem, change_flag
          prod.reload
          expect(prod.name).to eq "name"
          expect(Product.count).to eq 1
          expect(change_flag.value).to eq false
        end

        it "creates product if necessary" do
          expect{subject.create_or_update_product! art_elem, change_flag}.to change(Product, :count).from(0).to(1)
          p = Product.first
          expect(p.name).to eq "name"
          expect(p.unique_identifier).to eq "UAPARTS-uid"
          expect(p.importer).to eq imp
          expect(change_flag.value).to eq true
        end
      end

      it "skips Style/Article if ArticleNumber element is blank or missing" do
        expect(art_elem).to receive(:text).with("ArticleNumber").and_return nil
        subject.create_or_update_product! art_elem, change_flag
        expect(Product.count).to eq 0
      end
    end

    describe "create_or_update_variants!" do
      let(:art_elem) do
        doc_string = include_variants(doc, ["1"])
        short_doc = REXML::Document.new(doc_string)
        REXML::XPath.match(short_doc, "//Article").first
      end

      it "updates variant if it exists and has been changed" do
        v = prod.variants.create!(variant_identifier: "sku 1")
        subject.create_or_update_variants!(prod, art_elem, change_flag, described_class::PrepackErrorLog.new)
        v.reload
        expect(v.variant_identifier).to eq "sku 1"
        expect(v.custom_value(cdefs[:var_upc])).to eq "upc num 1"
        expect(v.custom_value(cdefs[:var_article_number])).to eq "var art 1"
        expect(v.custom_value(cdefs[:var_description])).to eq "var descr 1"
        expect(v.custom_value(cdefs[:var_hts_code])).to eq "1111111111"
        expect(Variant.count).to eq 1
        expect(change_flag.value).to eq true
      end

      it "doesn't update variant if unchanged" do
        v = prod.variants.create!(variant_identifier: "sku 1")
        v.find_and_set_custom_value(cdefs[:var_upc], "upc num 1")
        v.find_and_set_custom_value(cdefs[:var_article_number], "var art 1")
        v.find_and_set_custom_value(cdefs[:var_description], "var descr 1")
        v.find_and_set_custom_value(cdefs[:var_hts_code], "1111111111")
        v.save!
        subject.create_or_update_variants!(prod, art_elem, change_flag, described_class::PrepackErrorLog.new)
        expect(change_flag.value).to eq false
      end

      it "adds variant to product if it doesn't exist" do
        expect{ subject.create_or_update_variants!(prod, art_elem, change_flag, described_class::PrepackErrorLog.new) }.to change(Variant, :count).from(0).to(1)
        v = Variant.first
        expect(v.variant_identifier).to eq "sku 1"
        expect(v.custom_value(cdefs[:var_upc])).to eq "upc num 1"
        expect(v.custom_value(cdefs[:var_article_number])).to eq "var art 1"
        expect(v.custom_value(cdefs[:var_description])).to eq "var descr 1"
        expect(v.custom_value(cdefs[:var_hts_code])).to eq "1111111111"
        expect(change_flag.value).to eq true
      end

      it "skips variant if SKU is missing" do
        art_elem.elements.delete("//SKU")
        subject.create_or_update_variants!(prod, art_elem, change_flag, described_class::PrepackErrorLog.new)
        expect(Variant.count).to eq 0
        expect(change_flag.value).to eq false
      end

      context "prepacks" do
        let(:prepack_prod) { Factory(:product, unique_identifier: 'UAPARTS-1271424-437', importer: prod.importer )}
        let!(:var_1) do
          var = Factory(:variant, variant_identifier: '1271424-43700-SM', product: prepack_prod)
          var.update_custom_value!(cdefs[:var_upc], 'upc a')
          var.update_custom_value!(cdefs[:var_article_number], 'article a')
          var.update_custom_value!(cdefs[:var_description], 'descr a')
          var.update_custom_value!(cdefs[:var_hts_code], 'hts a')
          var.update_custom_value!(cdefs[:var_units_per_inner_pack], 7346)
          var
        end
        let!(:var_2) do
          var = Factory(:variant, variant_identifier: '1271424-43700-LG', product: prepack_prod)
          var.update_custom_value!(cdefs[:var_upc], 'upc b')
          var.update_custom_value!(cdefs[:var_article_number], 'article b')
          var.update_custom_value!(cdefs[:var_description], 'descr b')
          var.update_custom_value!(cdefs[:var_hts_code], 'hts b')
          var.update_custom_value!(cdefs[:var_units_per_inner_pack], 3678)
          var
        end
        let(:art_elem_with_prepack) do
          doc_string = include_variants(doc, ["2"])
          short_doc = REXML::Document.new(doc_string)
          prepack_elem = REXML::XPath.match(short_doc, "//Article").first
          prepack_elem.get_elements("ArticleAttr[Code[@Type='ArticleType']]/Code")[0].text = "ZPPK"
          prepack_elem
        end

        it "adds variants to product based on prepack info" do
          error_log = described_class::PrepackErrorLog.new
          subject.create_or_update_variants!(prod, art_elem_with_prepack, change_flag, error_log)
          prod_variants = Variant.where(product_id:prod)
          expect(prod_variants.count).to eq 2
          prepack_var_1, prepack_var_2 = prod_variants

          expect(prod.get_custom_value(cdefs[:prod_prepack]).value).to eq true

          expect(prepack_var_1.product).to eq prod
          expect(prepack_var_1.variant_identifier).to eq '1271424-43700-SM'
          expect(prepack_var_1.get_custom_value(cdefs[:var_upc]).value).to eq 'upc a'
          expect(prepack_var_1.get_custom_value(cdefs[:var_article_number]).value).to eq 'article a'
          expect(prepack_var_1.get_custom_value(cdefs[:var_description]).value).to eq 'descr a'
          expect(prepack_var_1.get_custom_value(cdefs[:var_hts_code]).value).to eq 'hts a'
          # This value is NOT copied from the DB variant record to the new variant record.  Instead, the new record's value comes from the XML.
          expect(prepack_var_1.get_custom_value(cdefs[:var_units_per_inner_pack]).value).to eq 55.44

          expect(prepack_var_2.product).to eq prod
          expect(prepack_var_2.variant_identifier).to eq '1271424-43700-LG'
          expect(prepack_var_2.get_custom_value(cdefs[:var_upc]).value).to eq 'upc b'
          expect(prepack_var_2.get_custom_value(cdefs[:var_article_number]).value).to eq 'article b'
          expect(prepack_var_2.get_custom_value(cdefs[:var_description]).value).to eq 'descr b'
          expect(prepack_var_2.get_custom_value(cdefs[:var_hts_code]).value).to eq 'hts b'
          expect(prepack_var_2.get_custom_value(cdefs[:var_units_per_inner_pack]).value).to eq 789

          expect(change_flag).to eq true
          expect(error_log.has_errors?).to eq false
        end

        it "skips variants that already exist on the product" do
          error_log = described_class::PrepackErrorLog.new

          var = prod.variants.create!(variant_identifier: "1271424-43700-SM")
          var.update_custom_value!(cdefs[:var_upc], 'upc a')
          var.update_custom_value!(cdefs[:var_article_number], 'article a')
          var.update_custom_value!(cdefs[:var_description], 'descr a')
          var.update_custom_value!(cdefs[:var_hts_code], 'hts a')
          var.update_custom_value!(cdefs[:var_units_per_inner_pack], 55.44)

          subject.create_or_update_variants!(prod, art_elem_with_prepack, change_flag, error_log)
          prod_variants = Variant.where(product_id:prod)
          expect(prod_variants.count).to eq 2
          unchanged_prepack_var, prepack_var = prod_variants

          expect(prod.get_custom_value(cdefs[:prod_prepack]).value).to eq true

          expect(unchanged_prepack_var.variant_identifier).to eq '1271424-43700-SM'

          expect(prepack_var.product).to eq prod
          expect(prepack_var.variant_identifier).to eq '1271424-43700-LG'
          expect(prepack_var.get_custom_value(cdefs[:var_upc]).value).to eq 'upc b'
          expect(prepack_var.get_custom_value(cdefs[:var_article_number]).value).to eq 'article b'
          expect(prepack_var.get_custom_value(cdefs[:var_description]).value).to eq 'descr b'
          expect(prepack_var.get_custom_value(cdefs[:var_hts_code]).value).to eq 'hts b'
          expect(prepack_var.get_custom_value(cdefs[:var_units_per_inner_pack]).value).to eq 789

          expect(change_flag).to eq true
          expect(error_log.has_errors?).to eq false
        end

        it "logs error if specified product not found" do
          error_log = described_class::PrepackErrorLog.new

          prepack_prod.destroy
          var_1.destroy
          var_2.destroy

          subject.create_or_update_variants!(prod, art_elem_with_prepack, change_flag, error_log)
          expect(prod.get_custom_value(cdefs[:prod_prepack]).value).to eq true
          expect(Variant.where(product_id:prod).count).to eq 0

          expect(change_flag).to eq true
          expect(error_log.has_errors?).to eq true
          expect(error_log.missing_products.length).to eq 1
          expect(error_log.missing_products[0]).to eq '1271424-437'
          expect(error_log.missing_variants.length).to eq 0
          expect(error_log.malformed_products.length).to eq 0
        end

        it "logs error if specified variant not found" do
          error_log = described_class::PrepackErrorLog.new

          var_1.destroy
          subject.create_or_update_variants!(prod, art_elem_with_prepack, change_flag, error_log)
          expect(prod.get_custom_value(cdefs[:prod_prepack]).value).to eq true
          variant_arr = Variant.where(product_id:prod)
          expect(variant_arr.count).to eq 1
          expect(variant_arr[0].variant_identifier).to eq '1271424-43700-LG'

          expect(change_flag).to eq true
          expect(error_log.has_errors?).to eq true
          expect(error_log.missing_products.length).to eq 0
          expect(error_log.missing_variants.length).to eq 1
          expect(error_log.missing_variants[0].product).to eq '1271424-437'
          expect(error_log.missing_variants[0].variant).to eq '1271424-43700-SM'
          expect(error_log.malformed_products.length).to eq 0
        end

        it "logs error if specified product code malformed" do
          error_log = described_class::PrepackErrorLog.new

          component_sku_elem_arr = REXML::XPath.match(doc, "//Article/UPC/BOMComponent/ComponentSKU")
          component_sku_elem_arr.each do |component_sku_elem|
            # Does not contain a hyphen: that qualifies it as "malformed".
            component_sku_elem.text = '1234567_123456_SML'
          end

          subject.create_or_update_variants!(prod, art_elem_with_prepack, change_flag, error_log)
          expect(prod.get_custom_value(cdefs[:prod_prepack]).value).to eq true
          variant_arr = Variant.where(product_id:prod)
          expect(variant_arr.count).to eq 0

          expect(change_flag).to eq true
          expect(error_log.has_errors?).to eq true
          expect(error_log.missing_products.length).to eq 0
          expect(error_log.missing_variants.length).to eq 0
          # Dupe value should have been removed.
          expect(error_log.malformed_products.length).to eq 1
          expect(error_log.malformed_products[0]).to eq '1234567_123456_SML'
        end
      end

    end

    describe "create_or_update_classi!" do
      let!(:classi) do
        c = Factory(:classification, product: prod, country: subject.ca)
        c.update_custom_value!(cdefs[:class_customs_description], "old descr")
        c
      end

      it "updates product's classification, if it already exists and has been changed" do
        expect(subject).to receive(:create_or_update_tariff!).with(classi, ["1111111111"], change_flag)
        subject.create_or_update_classi! prod, "new descr", ["1111111111"], change_flag
        classi.reload
        expect(classi.custom_value(cdefs[:class_customs_description])).to eq "new descr"
        expect(change_flag.value).to eq true
      end

      it "doesn't update product's classification if it hasn't been changed" do
        expect(subject).to receive(:create_or_update_tariff!).with(classi, ["1111111111"], change_flag)
        subject.create_or_update_classi! prod, "old descr", ["1111111111"], change_flag
        expect(change_flag.value).to eq false
      end

      it "creates a CA classification if product doesn't have one" do
        prod.classifications.destroy_all
        expect(subject).to receive(:create_or_update_tariff!).with(instance_of(Classification), ["1111111111"], change_flag)
        expect{ subject.create_or_update_classi! prod, "descr", ["1111111111"], change_flag }.to change(Classification, :count).from(0).to(1)
        expect(change_flag.value).to eq true
      end
    end

    describe "create_or_update_tariff!" do
      let!(:classi) { Factory(:classification, product: prod, country: subject.ca)}

      context "with single HTS" do
        it "updates classification's tariff if it already exists and has been changed" do
          tr = Factory(:tariff_record, classification: classi, hts_1: "1111111111")
          subject.create_or_update_tariff! classi, ["2222222222"], change_flag
          tr.reload
          expect(tr.hts_1).to eq "2222222222"
          expect(change_flag.value).to eq true
        end

        it "doesn't update tariff if it hasn't been changed" do
          tr = Factory(:tariff_record, classification: classi, hts_1: "1111111111")
          subject.create_or_update_tariff! classi, ["1111111111"], change_flag
          tr.reload
          expect(tr.hts_1).to eq "1111111111"
          expect(change_flag.value).to eq false
        end

        it "creates a tariff if classification doesn't have one" do
          expect{subject.create_or_update_tariff! classi, ["1111111111"], change_flag}.to change(TariffRecord, :count).from(0).to(1)
          classi.reload
          expect(classi.tariff_records.first.hts_1).to eq "1111111111"
          expect(change_flag.value).to eq true
        end
      end

      it "removes tariff if given more than one HTS" do
        Factory(:tariff_record, classification: classi, hts_1: "1111111111")
        classi.reload
        expect{subject.create_or_update_tariff! classi, ["1111111111","2222222222"], change_flag}.to change(TariffRecord, :count).from(1).to(0)
        expect(change_flag.value).to eq true
      end
    end

    describe "set_var_custom_values!" do
      let(:var_fields) { {var_upc: 'ABC123'} }

      it "sets custom values" do
        subject.set_var_custom_values! prod, var_fields, change_flag
        expect(prod.custom_value(cdefs[:var_upc])).to eq "ABC123"
        expect(change_flag.value).to eq true
      end

      it "doesn't set values if unchanged" do
        prod.update_custom_value!(cdefs[:var_upc], "ABC123")
        subject.set_var_custom_values! prod, var_fields, change_flag
        expect(change_flag.value).to eq false
      end
    end

    describe "pluck_unique_hts_values" do
      let!(:var_1) do
        v = Factory(:variant, product: prod)
        v.update_custom_value!(cdefs[:var_hts_code], "1111111111")
        v
      end
      let!(:var_2) do
        v = Factory(:variant, product: prod)
        v.update_custom_value!(cdefs[:var_hts_code], "2222222222")
        v
      end

      it "grabs all variant hts values for a given product" do
        expect(subject.pluck_unique_hts_values prod).to eq ["1111111111", "2222222222"]
      end

      it "removes duplicates" do
        v3 = Factory(:variant, product: prod)
        v3.update_custom_value!(cdefs[:var_hts_code], "1111111111")
        expect(subject.pluck_unique_hts_values prod).to eq ["1111111111", "2222222222"]
      end
    end
  end

  describe "error emailing" do
    it "sends error email" do
      error_log = described_class::PrepackErrorLog.new
      error_log.missing_products = ['ABC', 'DEF']
      error_log.malformed_products = ['GHI', 'JKL']
      error_log.missing_variants = [described_class::PrepackErrorLogMissingVariant.new('MNO', 'PQR'), described_class::PrepackErrorLogMissingVariant.new('STU', 'VWX')]

      subject.send_error_email error_log, 'file.xml'

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "support@vandegriftinc.com" ]
      expect(mail.subject).to eq "UA Article Master Parser: Products and/or Variants not found"
      expect(mail.body).to match(/The following errors were encountered when processing file.xml: \<br\> \<br\>These products could not be found:\<br\>ABC\<br\>DEF\<br\>\<br\>These variants could not be found \(product \/ variant\):\<br\>\<br\>MNO \/ PQR\<br\>STU \/ VWX\<br\>\<br\>These product codes did not fit the expected format:\<br\>GHI\<br\>JKL\<br\>/)
    end

    # Represents fake condition that wouldn't occur in real world usage.
    it "sends blank error email" do
      error_log = described_class::PrepackErrorLog.new
      # Has no missing products, etc.

      subject.send_error_email error_log, 'file.xml'

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.body).to match(/The following errors were encountered when processing file.xml: \<br\> \<br\>/)
      expect(mail.body).not_to match(/These products could not be found/)
      expect(mail.body).not_to match(/These variants could not be found/)
      expect(mail.body).not_to match(/These product codes did not fit the expected format/)
    end
  end

end