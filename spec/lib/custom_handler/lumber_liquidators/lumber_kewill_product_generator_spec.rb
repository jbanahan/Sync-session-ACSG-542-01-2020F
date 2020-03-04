describe OpenChain::CustomHandler::LumberLiquidators::LumberKewillProductGenerator do

  describe "run_schedulable" do
    subject { described_class }

    let (:us) { Factory(:country, iso_code: "US")}
    let (:importer) { with_customs_management_id(Factory(:importer), "LUMBER")}
    let (:cdefs) { subject.new("", {}).custom_defs }
    let! (:product) {
      p = Factory(:product, importer: importer, unique_identifier: "0000000123", name: "Description")
      c = p.classifications.create! country: us
      c.update_custom_value!(cdefs[:class_special_program_indicator], "SP")
      c.tariff_records.create! hts_1: "12345678"
      p.update_custom_value!(cdefs[:prod_country_of_origin], "CO")
      p.update_custom_value!(cdefs[:prod_cvd_case], "CVDCASE")
      p.update_custom_value!(cdefs[:prod_add_case], "ADDCASE")

      p
    }

    it "finds files to sync and sends them" do
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable

      expect(data).not_to be_nil
      doc = REXML::Document.new(data)

      parent = REXML::XPath.first doc, "/requests/request/kcData/parts/part"
      expect(parent.text "id/partNo").to eq "123"
      expect(parent.text "id/custNo").to eq "LUMBER"
      expect(parent.text "id/dateEffective").to eq "20140101"
      expect(parent.text "dateExpiration").to eq "20991231"
      expect(parent.text "styleNo").to eq "123"
      expect(parent.text "descr").to eq "DESCRIPTION"
      expect(parent.text "CatTariffClassList/CatTariffClass/seqNo").to eq "1"
      expect(parent.text "CatTariffClassList/CatTariffClass/tariffNo").to eq "12345678"
      expect(parent.text "CatTariffClassList/CatTariffClass/spiPrimary").to eq "SP"
      expect(parent.text "countryOrigin").to eq "CO"

      penalties = REXML::XPath.match(parent, "CatPenaltyList/CatPenalty").to_a
      expect(penalties.length).to eq 2

      p = penalties.first
      expect(p.text "partNo").to eq "123"
      expect(p.text "custNo").to eq "LUMBER"
      expect(p.text "dateEffective").to eq "20140101"
      expect(p.text "penaltyType").to eq "CVD"
      expect(p.text "caseNo").to eq "CVDCASE"

      p = penalties.second
      expect(p.text "penaltyType").to eq "ADA"
      expect(p.text "caseNo").to eq "ADDCASE"      
    end

    it "does not sync previously synced products" do
      product.sync_records.create! sent_at: Time.zone.now, trading_partner: "Kewill", confirmed_at: (Time.zone.now + 1.minute)
      expect_any_instance_of(subject).not_to receive(:ftp_file)
      subject.run_schedulable
    end

    it "includes supplemental tariffs" do
      SpecialTariffCrossReference.create! import_country_iso: "US", hts_number: "12345678", special_hts_number: "9999999999", effective_date_start: (Time.zone.now.to_date)
      
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable

      expect(data).not_to be_nil
      part = REXML::XPath.first REXML::Document.new(data), "/requests/request/kcData/parts/part"
      expect(part).not_to be_nil
      expect(part).to have_xpath_value("CatTariffClassList/CatTariffClass[seqNo = '1']/tariffNo", "9999999999")
      expect(part).to have_xpath_value("CatTariffClassList/CatTariffClass[seqNo = '2']/tariffNo", "12345678")
    end

    it "overrides 301 supplemental tariffs if an exlusion is set on the product" do
      SpecialTariffCrossReference.create! import_country_iso: "US", hts_number: "12345678", special_hts_number: "9999999999", effective_date_start: (Time.zone.now.to_date), special_tariff_type: "301"
      
      product.update_custom_value! cdefs[:prod_301_exclusion_tariff], "99038812"
      data = nil
      expect_any_instance_of(subject).to receive(:ftp_file) do |instance, file|
        data = file.read
      end

      subject.run_schedulable

      expect(data).not_to be_nil
      part = REXML::XPath.first REXML::Document.new(data), "/requests/request/kcData/parts/part"
      expect(part).not_to be_nil
      expect(part).to have_xpath_value("CatTariffClassList/CatTariffClass[seqNo = '1']/tariffNo", "99038812")
      expect(part).to have_xpath_value("CatTariffClassList/CatTariffClass[seqNo = '2']/tariffNo", "12345678")
    end
  end

  describe "write_row_to_xml" do

    subject { described_class.new("LUMBER", {"alliance_customer_number" => "LUMBER", "strip_leading_zeros" => true, "use_unique_identifier" => true}) }
    
    let (:row) {
      # This is what a file row without FDA information will look like (description should upcase)
      ["STYLE", "description", "1234567890", "CO", nil]
    }

    let (:parent) { REXML::Document.new("<root></root>").root }

    context "with special tariffs" do
      let! (:special_tariff) { SpecialTariffCrossReference.create! import_country_iso: "US", hts_number: "1234567890", special_hts_number: "0987654321", country_origin_iso: "CO", effective_date_start: (Time.zone.now.to_date), effective_date_end: (Time.zone.now.to_date + 1.day) }

      it "includes special tariffs as first tariff record if present" do
        subject.write_row_to_xml parent, 1, row

        tariffs = []
        parent.elements.each("part/CatTariffClassList/CatTariffClass") {|el| tariffs << el}
        expect(tariffs.length).to eq 2

        t = tariffs.first
        expect(t.text "seqNo").to eq "1"
        expect(t.text "tariffNo").to eq "0987654321"

        t = tariffs.second
        expect(t.text "seqNo").to eq "2"
        expect(t.text "tariffNo").to eq "1234567890"
      end

      it "adds exclusion 301 tariff and ignores standard 301 tariff" do
        row[4] = "99038812"
        special_tariff.update! special_tariff_type: "301"

        subject.write_row_to_xml parent, 1, row

        tariffs = []
        parent.elements.each("part/CatTariffClassList/CatTariffClass") {|el| tariffs << el}
        expect(tariffs.length).to eq 2

        t = tariffs.first
        expect(t.text "seqNo").to eq "1"
        expect(t.text "tariffNo").to eq "99038812"

        t = tariffs.second
        expect(t.text "seqNo").to eq "2"
        expect(t.text "tariffNo").to eq "1234567890"
      end

    end
  end
end