describe OpenChain::CustomHandler::Polo::PoloAbstractProductXmlGenerator do

  subject { 
    s = described_class.new
    allow(s).to receive(:sync_code).and_return "abstract_code"
    s
  }

  describe "sync_xml" do
    let! (:product) {
      Factory(:product)
    }

    it "finds and sends xml file for products that need syncing" do
      # This is basically just testing the query method...

      expect(subject).to receive(:write_row_to_xml).with(instance_of(REXML::Element), 0, [product.id])
      f = nil
      begin
        f = subject.sync_xml
        expect(f).to be_instance_of(Tempfile)
      ensure
        f.close! unless f.nil? || f.closed?
      end
      
    end

    it "does not find products that are already synced" do
      expect(subject).not_to receive(:write_row_to_xml)
      product.sync_records.create! trading_partner: "abstract_code", sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)

      expect(subject.sync_xml).to be_nil
    end
  end

  describe "write_row_to_xml" do
    before :all do 
      described_class.new.cdefs
    end

    after :all do 
      CustomDefinition.destroy_all
    end

    let (:cdefs) { subject.cdefs }
    let (:xml) { REXML::Element.new "root" }
    let (:us) { Factory(:country, iso_code: "US") }
    let (:ca) { Factory(:country, iso_code: "CA") }
    let (:product) { 
      p = Factory(:product, unique_identifier: "uid", name: "Long Description")
      [us, ca].each do |co|
        c = p.classifications.create! country_id: co.id
        c.tariff_records.create! hts_1: "1234567890"
        c.tariff_records.create! hts_1: "9876543210"
      end
      p
    }
    let (:row) { [product.id] }

    let! (:us_official_tariff) {
      ot = OfficialTariff.create! country_id: us.id, hts_code: "1234567890", general_rate: "Common Rate"
      ot.create_official_quota! category: "CAT"
      ot
    }

    def xp xml, xpath, expected_value
      expect(xml).to have_xpath_value(xpath, expected_value)
    end

    context "with all values set" do
      before :each do 
        populate_custom_values(product, cdefs)
        populate_custom_values(product.classifications.first, cdefs)
      end

      it "adds Product element to given xml" do
        subject.write_row_to_xml xml, 0, row

        p = xml.children.first
        expect(p.name).to eq "Product"

        xp(p, "Style", "uid")
        xp(p, "FibreContent", "prod_fiber_content")
        xp(p, "LongDesc", "Long Description")
        xp(p, "ShortDesc", "prod_rl_short_description")
        xp(p, "KnitWoven", "prod_knit_woven")
        xp(p, "KnitType", "prod_knit_type")
        xp(p, "BottomType", "prod_type_of_bottom")
        xp(p, "FuncNeckOpening", "Y")
        xp(p, "SignifNaP", "Y")
        xp(p, "WaterTest", "prod_pass_water_resistant_test")
        xp(p, "CoatingType", "prod_type_of_coating")
        xp(p, "PaddOrFill", "prod_padding_or_filling")
        xp(p, "Down", "Y")
        xp(p, "WaistType", "prod_tightening_at_waist")
        xp(p, "Denim", "prod_denim")
        xp(p, "DenimCol", "prod_denim_color")
        xp(p, "Corduroy", "Y")
        xp(p, "BackPanels", "#{cdefs[:total_back_panels].id}")
        xp(p, "ShtFallAboveKnee", "Y")
        xp(p, "MeshLining", "Y")
        xp(p, "ElasticWaist", "Y")
        xp(p, "FunctionalDrawstring", "Y")
        xp(p, "CoverCrownHead", "Y")
        xp(p, "WholePartialBraid", "prod_wholly_or_partially_braid")
        xp(p, "DyedType", "prod_yarn_dyed")
        xp(p, "WarpW", "prod_colors_in_warp_weft")
        xp(p, "SizeScale", "prod_size_scale")
        xp(p, "FabricType", "prod_type_of_fabric")
        xp(p, "FuncFly", "Y")
        xp(p, "TightningCuffs", "Y")
        xp(p, "Royalty", "#{cdefs[:royalty_percentage].id.to_f}")
        xp(p, "FDAIndic", "prod_fda_indicator")
        xp(p, "FDAProdCode", "class_fda_product_code")
        xp(p, "SetType", "class_set_type")
        
        xp(p, "StitchCountWeight/TwocmVert", "prod_stitch_count_vertical")
        xp(p, "StitchCountWeight/TwocmHori", "prod_stitch_count_horizontal")
        xp(p, "StitchCountWeight/GmSquM", "prod_grams_square_meter")
        xp(p, "StitchCountWeight/OzSqYd", "#{cdefs[:ounces_sq_yd].id.to_f}")
        xp(p, "StitchCountWeight/WeightFabric", "prod_weight_of_fabric")
        
        xp(p, "Sleepwear/FormLooseFit", "prod_form_fitting_or_loose_fitting")
        xp(p, "Sleepwear/FlyOpenPlacket", "Y")
        xp(p, "Sleepwear/EmbellishOrnament", "Y")
        xp(p, "Sleepwear/Sizing", "prod_sizing")
        xp(p, "Sleepwear/SleepwearDept", "Y")
        xp(p, "Sleepwear/PcsinSet", "#{cdefs[:pcs_in_set].id}")
        xp(p, "Sleepwear/SoldasSet", "Y")

        xp(p, "Footwear/Welted", "Y")
        xp(p, "Footwear/CoverAnkle", "Y")
        xp(p, "Footwear/JapLeather", "Y")

        xp(p, "HandbagsScarves/Lengthcm", "#{cdefs[:length_cm].id.to_f}")
        xp(p, "HandbagsScarves/Widthcm", "#{cdefs[:width_cm].id.to_f}")
        xp(p, "HandbagsScarves/Heightcm", "#{cdefs[:height_cm].id.to_f}")
        xp(p, "HandbagsScarves/Lengthin", "#{cdefs[:length_in].id.to_f}")
        xp(p, "HandbagsScarves/Widthin", "#{cdefs[:width_in].id.to_f}")
        xp(p, "HandbagsScarves/Heightin", "#{cdefs[:height_in].id.to_f}")
        xp(p, "HandbagsScarves/StrapWidth", "prod_strap_width")
        xp(p, "HandbagsScarves/SecureClosure", "Y")
        xp(p, "HandbagsScarves/ClosureType", "prod_closure_type")
        xp(p, "HandbagsScarves/MultipleCompart", "Y")

        xp(p, "Gloves/GlovesFourchettes", "Y")
        xp(p, "Gloves/GlovesLined", "Y")
        xp(p, "Gloves/Seamed", "Y")

        xp(p, "Jewelry/Components", "prod_components")
        xp(p, "Jewelry/CostComponents", "prod_cost_of_component")
        xp(p, "Jewelry/WeightComponents", "prod_weight_of_components")
        xp(p, "Jewelry/CoatedFilledPlated", "prod_coated_filled_plated")
        xp(p, "Jewelry/TypeCoatedFilledPlated", "prod_coated_filled_plated_type")
        xp(p, "Jewelry/PreciousSemiPrecious", "prod_precious_semi_precious")

        xp(p, "Umbrella/TelescopicShaft", "Y")

        xp(p, "Sanitation/EUSanitation", "Y")
        xp(p, "Sanitation/JapanSanitation", "Y")
        xp(p, "Sanitation/KoreaSanitaion", "Y")

        hts = REXML::XPath.each(p, "HTS").to_a
        expect(hts.length).to eq 4 # 2 for US / 2 for CA

        expect(hts[0]).to have_xpath_value("HTSCountry", "US")
        expect(hts[0]).to have_xpath_value("HTSTariffCode", "1234567890")
        expect(hts[0]).to have_xpath_value("HTSQuotaCategory", "CAT")
        expect(hts[0]).to have_xpath_value("HTSGeneralRate", "Common Rate")

        expect(hts[1]).to have_xpath_value("HTSCountry", "US")
        expect(hts[1]).to have_xpath_value("HTSTariffCode", "9876543210")
        expect(hts[1]).to have_xpath_value("HTSQuotaCategory", nil)
        expect(hts[1]).to have_xpath_value("HTSGeneralRate", nil)

        expect(hts[2]).to have_xpath_value("HTSCountry", "CA")
        expect(hts[2]).to have_xpath_value("HTSTariffCode", "1234567890")
        expect(hts[2]).to have_xpath_value("HTSQuotaCategory", nil)
        expect(hts[2]).to have_xpath_value("HTSGeneralRate", nil)

        expect(hts[3]).to have_xpath_value("HTSCountry", "CA")
        expect(hts[3]).to have_xpath_value("HTSTariffCode", "9876543210")
        expect(hts[3]).to have_xpath_value("HTSQuotaCategory", nil)
        expect(hts[3]).to have_xpath_value("HTSGeneralRate", nil)
      end
    end
  end

  describe "run_schedulable" do
    subject { described_class }
    let (:tempfile) { instance_double(Tempfile) }

    it "runs until sync_xml returns nil" do
      expect_any_instance_of(subject).to receive(:sync_xml).and_return tempfile
      expect_any_instance_of(subject).to receive(:sync_xml).and_return tempfile
      expect_any_instance_of(subject).to receive(:sync_xml).and_return nil
      expect_any_instance_of(subject).to receive(:ftp_file).with(tempfile).exactly(2).times
      
      subject.run_schedulable
    end
  end
end