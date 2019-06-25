describe OpenChain::CustomHandler::Polo::PoloAxProductGenerator do

  before :all do 
    described_class.new.cdefs
  end

  after :all do 
    CustomDefinition.destroy_all
  end

  let (:cdefs) { subject.cdefs }
  let (:product) { Factory(:product, unique_identifier: "uid") }
  let (:exported_product) { 
    product.update_column(:updated_at, Time.zone.now - 7.days)
    c = product.classifications.create! country_id: Factory(:country, iso_code: "US").id
    c.tariff_records.create hts_1: "9999999999"

    product.update_custom_value! cdefs[:ax_export_status], "EXPORTED"
    product.update_custom_value! cdefs[:fabric_1], "FABRIC 1"
    product.update_custom_value! cdefs[:fabric_type_1], "FABRIC TYPE 1"
    product.update_custom_value! cdefs[:fabric_percent_1], 10
    product.update_custom_value! cdefs[:fiber_content], "FIBER CONTENT"
    product.update_custom_value! cdefs[:msl_gcc_desc], "GCC DESC"
    product.update_custom_value! cdefs[:non_textile], "N"

    product
  }

  describe "sync_csv" do

    it "syncs a product" do
      exported_product

      file = subject.sync_csv
      expect(file).not_to be_nil
      file.rewind
      data = file.read
      rows = CSV.parse(data)
      expect(rows.length).to eq 2
      # Just make sure the first column of the first row is the expected header value
      expect(rows[0][0]).to eq "GFE+ Material Number"

      # Make sure blank columns are blank strings
      expect(rows[1][12]).to eq ""

      exported_product.reload
      expect(exported_product.custom_value(cdefs[:ax_updated_without_change])).to eq false
      r = exported_product.sync_records.first
      expect(r).not_to be_nil
      expect(r.trading_partner).to eq 'AX'
    end

    it "does not sync a product already synced unless ax_updated_without_change flag has been set" do
      exported_product.sync_records.create! trading_partner: "AX", sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
      expect(subject.sync_csv).to be_nil

      product.update_custom_value! cdefs[:ax_updated_without_change], true
      expect(subject.sync_csv).to_not be_nil
    end

    it "does not sync a product sent less than 24 hours ago" do
      exported_product.sync_records.create! trading_partner: "AX", sent_at: ((Time.zone.now - 23.hours) - 59.minutes), confirmed_at: nil
      expect(subject.sync_csv).to be_nil
    end

    it "sends a product that was sent less that 24 hours ago if the product was updated since being sent" do
      exported_product.touch
      exported_product.sync_records.create! trading_partner: "AX", sent_at: ((Time.zone.now - 23.hours) - 59.minutes), confirmed_at: ((Time.zone.now - 20.hours) - 59.minutes)

      expect(subject.sync_csv).not_to be_nil
    end

    it "resends a product sent over 24 hours without an acknowledgement" do
      exported_product.sync_records.create! trading_partner: "AX", sent_at: ((Time.zone.now - 24.hours) - 1.minute), confirmed_at: nil
      expect(subject.sync_csv).not_to be_nil
    end

    it "syncs a product with a custom Ax Export status" do
      exported_product.update_custom_value! cdefs[:ax_export_status], ""
      exported_product.update_custom_value! cdefs[:ax_export_status_manual], "EXPORTED"

      expect(subject.sync_csv).to_not be_nil
    end

    context "with missing data" do
      it "does not sync a product without an EXPORTED Ax Export Status" do
        exported_product.update_custom_value! cdefs[:ax_export_status], ""

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without an classification" do
        exported_product.classifications.destroy_all

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a tariff 1" do
        exported_product.classifications.first.tariff_records.first.update_attributes! hts_1: ""

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a Fabric 1 value" do
        exported_product.update_custom_value! cdefs[:fabric_1], ""

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a Fabric Type 1 value" do
        exported_product.update_custom_value! cdefs[:fabric_type_1], ""

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a Fabric % 1 value" do
        exported_product.update_custom_value! cdefs[:fabric_percent_1], 0

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a Fiber Content value" do
        exported_product.update_custom_value! cdefs[:fiber_content], ""

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a GCC Description value" do
        exported_product.update_custom_value! cdefs[:msl_gcc_desc], ""

        expect(subject.sync_csv).to be_nil
      end

      it "does not sync a product without a Non-Textile Flag value" do
        exported_product.update_custom_value! cdefs[:non_textile], ""

        expect(subject.sync_csv).to be_nil
      end
    end
  end

  describe "preprocess_row" do
    let (:us) { Factory(:country, iso_code: "US") }

    let (:full_product) {
      classification = product.classifications.create! country_id: us.id
      classification.tariff_records.create! hts_1: "1234567890", hts_2: "0987654321", hts_3: "5678901234"
      classification.update_custom_value! cdefs[:set_type], "XXV"


      product.update_custom_value! cdefs[:msl_gcc_desc], "GCC"
      product.update_custom_value! cdefs[:gcc_description_2], "GCC2"
      product.update_custom_value! cdefs[:gcc_description_3], "GCC3"
      product.update_custom_value! cdefs[:depth_cm], 1
      product.update_custom_value! cdefs[:bottom_width_cm], 2
      product.update_custom_value! cdefs[:height_cm], 3
      product.update_custom_value! cdefs[:fabric_1], "f1"
      product.update_custom_value! cdefs[:fabric_2], "f2"
      product.update_custom_value! cdefs[:fabric_3], "f3"
      product.update_custom_value! cdefs[:fabric_4], "f4"
      product.update_custom_value! cdefs[:fabric_5], "f5"
      product.update_custom_value! cdefs[:fabric_6], "f6"
      product.update_custom_value! cdefs[:fabric_7], "f7"
      product.update_custom_value! cdefs[:fabric_8], "f8"
      product.update_custom_value! cdefs[:fabric_9], "f9"
      product.update_custom_value! cdefs[:fabric_10], "f10"
      product.update_custom_value! cdefs[:fabric_11], "f11"
      product.update_custom_value! cdefs[:fabric_12], "f12"
      product.update_custom_value! cdefs[:fabric_13], "f13"
      product.update_custom_value! cdefs[:fabric_14], "f14"
      product.update_custom_value! cdefs[:fabric_15], "f15"
      product.update_custom_value! cdefs[:fabric_type_1], "ft1"
      product.update_custom_value! cdefs[:fabric_type_2], "ft2"
      product.update_custom_value! cdefs[:fabric_type_3], "ft3"
      product.update_custom_value! cdefs[:fabric_type_4], "ft4"
      product.update_custom_value! cdefs[:fabric_type_5], "ft5"
      product.update_custom_value! cdefs[:fabric_type_6], "ft6"
      product.update_custom_value! cdefs[:fabric_type_7], "ft7"
      product.update_custom_value! cdefs[:fabric_type_8], "ft8"
      product.update_custom_value! cdefs[:fabric_type_9], "ft9"
      product.update_custom_value! cdefs[:fabric_type_10], "ft10"
      product.update_custom_value! cdefs[:fabric_type_11], "ft11"
      product.update_custom_value! cdefs[:fabric_type_12], "ft12"
      product.update_custom_value! cdefs[:fabric_type_13], "ft13"
      product.update_custom_value! cdefs[:fabric_type_14], "ft14"
      product.update_custom_value! cdefs[:fabric_type_15], "ft15"
      product.update_custom_value! cdefs[:fabric_percent_1], 1
      product.update_custom_value! cdefs[:fabric_percent_2], 2
      product.update_custom_value! cdefs[:fabric_percent_3], 3
      product.update_custom_value! cdefs[:fabric_percent_4], 4
      product.update_custom_value! cdefs[:fabric_percent_5], 5
      product.update_custom_value! cdefs[:fabric_percent_6], 6
      product.update_custom_value! cdefs[:fabric_percent_7], 7
      product.update_custom_value! cdefs[:fabric_percent_8], 8
      product.update_custom_value! cdefs[:fabric_percent_9], 9
      product.update_custom_value! cdefs[:fabric_percent_10], 10
      product.update_custom_value! cdefs[:fabric_percent_11], 11
      product.update_custom_value! cdefs[:fabric_percent_12], 12
      product.update_custom_value! cdefs[:fabric_percent_13], 13
      product.update_custom_value! cdefs[:fabric_percent_14], 14
      product.update_custom_value! cdefs[:fabric_percent_15], 15
      product.update_custom_value! cdefs[:knit_woven], "knit"
      # Add a newline in here to make sure it's stripped out
      product.update_custom_value! cdefs[:fiber_content], "fiber\ncontent"
      product.update_custom_value! cdefs[:common_name_1], "cn1"
      product.update_custom_value! cdefs[:common_name_2], "cn2"
      product.update_custom_value! cdefs[:common_name_3], "cn3"
      product.update_custom_value! cdefs[:scientific_name_1], "sn1"
      product.update_custom_value! cdefs[:scientific_name_2], "sn2"
      product.update_custom_value! cdefs[:scientific_name_3], "sn3"
      product.update_custom_value! cdefs[:fish_wildlife_origin_1], "fw1"
      product.update_custom_value! cdefs[:fish_wildlife_origin_2], "fw2"
      product.update_custom_value! cdefs[:fish_wildlife_origin_3], "fw3"
      product.update_custom_value! cdefs[:fish_wildlife_source_1], "fws1"
      product.update_custom_value! cdefs[:fish_wildlife_source_2], "fws2"
      product.update_custom_value! cdefs[:fish_wildlife_source_3], "fws3"
      product.update_custom_value! cdefs[:origin_wildlife], "origin"
      product.update_custom_value! cdefs[:semi_precious], true
      product.update_custom_value! cdefs[:semi_precious_type], "precious"
      product.update_custom_value! cdefs[:cites], true
      product.update_custom_value! cdefs[:fish_wildlife], false
      product.update_custom_value! cdefs[:meets_down_requirments], true
      product.update_custom_value! cdefs[:non_textile], "N"


      product
    }

    it "generates product rows" do
      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 1
      r = rows.first
      expect(r[0]).to eq "uid"
      expect(r[1]).to eq "US"
      expect(r[2]).to eq "0"
      expect(r[3]).to eq "1234.56.7890"
      expect(r[4]).to eq "0987.65.4321"
      expect(r[5]).to eq "5678.90.1234"
      expect(r[6]).to eq BigDecimal("1")
      expect(r[7]).to eq BigDecimal("2")
      expect(r[8]).to eq BigDecimal("3")
      expect(r[9]).to eq "ft1"
      expect(r[10]).to eq "f1"
      expect(r[11]).to eq BigDecimal("1")
      expect(r[12]).to eq "ft2"
      expect(r[13]).to eq "f2"
      expect(r[14]).to eq BigDecimal("2")
      expect(r[15]).to eq "ft3"
      expect(r[16]).to eq "f3"
      expect(r[17]).to eq BigDecimal("3")
      expect(r[18]).to eq "ft4"
      expect(r[19]).to eq "f4"
      expect(r[20]).to eq BigDecimal("4")
      expect(r[21]).to eq "ft5"
      expect(r[22]).to eq "f5"
      expect(r[23]).to eq BigDecimal("5")
      expect(r[24]).to eq "ft6"
      expect(r[25]).to eq "f6"
      expect(r[26]).to eq BigDecimal("6")
      expect(r[27]).to eq "ft7"
      expect(r[28]).to eq "f7"
      expect(r[29]).to eq BigDecimal("7")
      expect(r[30]).to eq "ft8"
      expect(r[31]).to eq "f8"
      expect(r[32]).to eq BigDecimal("8")
      expect(r[33]).to eq "ft9"
      expect(r[34]).to eq "f9"
      expect(r[35]).to eq BigDecimal("9")
      expect(r[36]).to eq "ft10"
      expect(r[37]).to eq "f10"
      expect(r[38]).to eq BigDecimal("10")
      expect(r[39]).to eq "ft11"
      expect(r[40]).to eq "f11"
      expect(r[41]).to eq BigDecimal("11")
      expect(r[42]).to eq "ft12"
      expect(r[43]).to eq "f12"
      expect(r[44]).to eq BigDecimal("12")
      expect(r[45]).to eq "ft13"
      expect(r[46]).to eq "f13"
      expect(r[47]).to eq BigDecimal("13")
      expect(r[48]).to eq "ft14"
      expect(r[49]).to eq "f14"
      expect(r[50]).to eq BigDecimal("14")
      expect(r[51]).to eq "ft15"
      expect(r[52]).to eq "f15"
      expect(r[53]).to eq BigDecimal("15")
      expect(r[54]).to eq "knit"
      expect(r[55]).to eq "fiber content"
      expect(r[56]).to eq "cn1"
      expect(r[57]).to eq "cn2"
      expect(r[58]).to eq "cn3"
      expect(r[59]).to eq "sn1"
      expect(r[60]).to eq "sn2"
      expect(r[61]).to eq "sn3"
      expect(r[62]).to eq "fw1"
      expect(r[63]).to eq "fw2"
      expect(r[64]).to eq "fw3"
      expect(r[65]).to eq "fws1"
      expect(r[66]).to eq "fws2"
      expect(r[67]).to eq "fws3"
      expect(r[68]).to eq "origin"
      expect(r[69]).to eq "1"
      expect(r[70]).to eq "precious"
      expect(r[71]).to eq "1"
      expect(r[72]).to eq "0"
      expect(r[73]).to eq "GCC"
      expect(r[74]).to eq "GCC2"
      expect(r[75]).to eq "GCC3"
      expect(r[76]).to eq "0"
      expect(r[77]).to eq "1"
      expect(r[78]).to eq "XXV"
    end

    it "handles legacy footwear fabric type conversion from Outer to Upper" do
      full_product.update_custom_value! cdefs[:fabric_type_1], "outer"
      full_product.update_custom_value! cdefs[:fabric_type_2], "outer"
      full_product.update_custom_value! cdefs[:fabric_type_3], "outer"
      full_product.update_custom_value! cdefs[:fabric_type_4], "Sole"

      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 1
      r = rows.first
      expect(r[9]).to eq "Upper"
      expect(r[12]).to eq "Upper"
      expect(r[15]).to eq "Upper"
      expect(r[18]).to eq "Sole"
    end

    it "does not convert Outer to Upper if there is no Sole fabric type following the Outer type" do
      full_product.update_custom_value! cdefs[:fabric_type_1], "outer"
      full_product.update_custom_value! cdefs[:fabric_type_2], "sole"
      full_product.update_custom_value! cdefs[:fabric_type_3], "outer"

      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 1
      r = rows.first
      expect(r[9]).to eq "Upper"
      expect(r[12]).to eq "sole"
      expect(r[15]).to eq "outer"
    end

    it "generates multiple rows per product, one per classification" do
      ca = Factory(:country, iso_code: "CA")
      c = full_product.classifications.create country_id: ca.id
      t = c.tariff_records.create! hts_1: "1234567890"

      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 2

      r = rows[0]
      # Just make sure the country data is in the expected order (sorted)
      expect(rows[0][1]).to eq "CA"
      expect(rows[1][1]).to eq "US"
    end

    it "generates multiple rows per product, one per tariff" do
      c = full_product.classifications.first
      t = c.tariff_records.create! hts_1: "5678901234"

      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 2

      r = rows[0]
      # Just make sure the country data is in the expected order (sorted)
      expect(rows[0][3]).to eq "1234.56.7890"
      expect(rows[1][3]).to eq "5678.90.1234"
    end

    it "generates a row without classification record" do
      full_product.classifications.destroy_all

      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 1

      r = rows.first
      expect(r[0]).to eq "uid"
      expect(r[1]).to be_nil
      expect(r[3]).to be_nil
      expect(r[4]).to be_nil
      expect(r[5]).to be_nil
    end

    it "converts length in to length cm" do
      full_product.update_custom_value! cdefs[:depth_in], 10
      full_product.update_custom_value! cdefs[:width_bottom_in], 100
      full_product.update_custom_value! cdefs[:height_in], 1000
      full_product.update_custom_value! cdefs[:depth_cm], nil
      full_product.update_custom_value! cdefs[:bottom_width_cm], nil
      full_product.update_custom_value! cdefs[:height_cm], nil

      rows = subject.preprocess_row({}, product_id: full_product.id)
      expect(rows.length).to eq 1

      r = rows.first
      expect(r[6]).to eq BigDecimal("25.4")
      expect(r[7]).to eq BigDecimal("254")
      expect(r[8]).to eq BigDecimal("2540")
    end

    context "with taiwan classification" do

      let (:taiwan) { Factory(:country, iso_code: "TW") }
      let! (:official_tariff) { OfficialTariff.create! hts_code: "123456789012", import_regulations: "A B MP1 C", country_id: taiwan.id }
      
      before :each do 
        c = full_product.classifications.first
        c.update_attributes! country_id: taiwan.id
        c.tariff_records.first.update_attributes! hts_1: "123456789012"
      end

      it "generates Taiwan data with MP1 checks" do
        rows = subject.preprocess_row({}, product_id: full_product.id)
        expect(rows.length).to eq 1

        r = rows.first
        expect(r[1]).to eq "TW"
        expect(r[2]).to eq "1"
        expect(r[3]).to eq "123456789012"
        expect(r[4]).to eq "0987654321"
        expect(r[5]).to eq "5678901234"
      end

      it "sends 0 for MP1 if tariff is not MP1" do
        official_tariff.update_attributes! import_regulations: "A"
        rows = subject.preprocess_row({}, product_id: full_product.id)

        r = rows.first
        expect(r[1]).to eq "TW"
        expect(r[2]).to eq "0"
      end
    end
    
  end

  describe "ftp_credentials" do
    it "uses correct file name" do
      now = Time.zone.parse("2018-10-11 12:45:11")
      c = nil
      Timecop.freeze(now) { c = subject.ftp_credentials }
      expect(c[:remote_file_name]).to eq "ax_export_20181011124511000.csv"
    end
  end
end
