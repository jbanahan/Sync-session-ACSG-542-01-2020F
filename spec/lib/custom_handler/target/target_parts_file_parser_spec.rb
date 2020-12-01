describe OpenChain::CustomHandler::Target::TargetPartsFileParser do

  let!(:inbound_file) do
    f = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return f
    allow(f).to receive(:s3_path).and_return "file.csv"
    f
  end

  let(:user) { FactoryBot(:user) }
  let!(:target) { with_customs_management_id(FactoryBot(:importer), "TARGEN") }

  describe "process_part_lines" do
    let(:file_data) { IO.read 'spec/fixtures/files/target_simple_part.csv' }
    let(:csv_data) { CSV.parse(file_data, { col_sep: "~", quote_char: "\007" }) }
    let!(:us) { FactoryBot(:country, iso_code: "US") }
    let(:cdefs) { subject.send(:cdefs) }
    let(:existing_product) { FactoryBot(:product, unique_identifier: "013022712-197312202", importer: target) }

    def expect_simple_product_data p
      expect(p.entity_snapshots.length).to eq 1
      expect(p.entity_snapshots.first.user).to eq user
      expect(p.entity_snapshots.first.context).to eq "file.csv"

      expect(p.custom_value(cdefs[:prod_part_number])).to eq "013022712"
      expect(p.custom_value(cdefs[:prod_vendor_order_point])).to eq "197312202"
      expect(p.inactive).to eq false
      expect(p.custom_value(cdefs[:prod_type])).to eq "Standard"
      expect(p.custom_value(cdefs[:prod_vendor_style])).to eq "00558390"
      expect(p.name).to eq "UT BUTTON DO XSM FRESH WHITE V2 (UV"
      expect(p.custom_value(cdefs[:prod_long_description])).to eq "Item Type - Button down shirts ABN Size"
      expect(p.custom_value(cdefs[:prod_tsca])).to eq true
      expect(p.custom_value(cdefs[:prod_aphis])).to eq true
      expect(p.custom_value(cdefs[:prod_usda])).to eq false
      expect(p.custom_value(cdefs[:prod_epa])).to eq true
      expect(p.custom_value(cdefs[:prod_cps])).to eq false
      expect(p.custom_value(cdefs[:prod_required_documents])).to eq "COMMERCIAL INVOICE\n PACKING LIST (FOREIGN)"

      classification = p.classifications.first
      expect(classification).not_to be_nil
      expect(classification.country).to eq us

      expect(classification.tariff_records.length).to eq 2
      t = classification.tariff_records.first

      expect(t.line_number).to eq 1
      expect(t.hts_1).to eq "9903889015"
      expect(t.hts_2).to eq "6206303041"
      expect(t.custom_value(cdefs[:tar_country_of_origin])).to eq "CN"
      expect(t.custom_value(cdefs[:tar_spi_primary])).to eq "SPI"
      expect(t.custom_value(cdefs[:tar_xvv])).to eq "X"
      expect(t.custom_value(cdefs[:tar_component_description])).to eq "Component Description"
      expect(t.custom_value(cdefs[:tar_add_case])).to eq "A123456789"
      expect(t.custom_value(cdefs[:tar_external_line_number])).to eq 1

      t = classification.tariff_records.second

      expect(t.line_number).to eq 2
      expect(t.hts_1).to eq "6206303003"
      expect(t.hts_2).to be_blank
      expect(t.custom_value(cdefs[:tar_country_of_origin])).to eq "VN"
      expect(t.custom_value(cdefs[:tar_spi_primary])).to eq "SPI2"
      expect(t.custom_value(cdefs[:tar_xvv])).to eq "Y"
      expect(t.custom_value(cdefs[:tar_component_description])).to eq "Component 2"
      expect(t.custom_value(cdefs[:tar_cvd_case])).to eq "C123456789"
      expect(t.custom_value(cdefs[:tar_external_line_number])).to eq 3
    end

    def uc obj, cdef_uid, v
      obj.update_custom_value! cdefs[cdef_uid], v
    end

    it "creates a simple product" do
      now = Time.zone.now
      p = subject.process_part_lines csv_data, now, user

      expect(p.unique_identifier).to eq "013022712-197312202"
      expect(p.importer).to eq target
      expect(p.last_exported_from_source).to eq now

      expect_simple_product_data(p)
      expect(inbound_file).to have_identifier(:part_number, "013022712-197312202", Product, p.id)
    end

    it "updates a product" do
      p = existing_product

      subject.process_part_lines csv_data, Time.zone.now, user
      p.reload

      expect_simple_product_data(p)
      expect(inbound_file).to have_identifier(:part_number, "013022712-197312202", Product, p.id)
    end

    it "does not save or snapshot if product did not change" do
      p = existing_product
      expect_any_instance_of(Product).not_to receive(:save!)
      expect(subject).to receive(:product_changed?).with(instance_of(MutableBoolean)).and_return false

      subject.process_part_lines csv_data, Time.zone.now, user
      p.reload

      expect(p.entity_snapshots.length).to eq 0
      expect(inbound_file).to have_identifier(:part_number, "013022712-197312202")
      # it shouldn't have identifer w/ full module info
      expect(inbound_file).not_to have_identifier(:part_number, "013022712-197312202", Product, p.id)
    end

    context "with complex data" do
      let (:file_data) { IO.read 'spec/fixtures/files/target_complex_part.csv' }

      it "creates a complex part" do
        p = subject.process_part_lines csv_data, Time.zone.now, user

        c = p.classifications.first
        tariffs = c.tariff_records.to_a
        expect(tariffs.length).to eq 2
        # All the "complex" data is associated with the second tariff
        t = tariffs.second

        expect(t.custom_value(cdefs[:tar_dot_box_number])).to eq "2A"
        expect(t.custom_value(cdefs[:tar_dot_program])).to eq "REI"

        expect(t.custom_value(cdefs[:tar_fda_product_code])).to eq "52AIX99"
        expect(t.custom_value(cdefs[:tar_fda_cargo_status])).to eq "A"
        expect(t.custom_value(cdefs[:tar_fda_food])).to eq false

        expect(t.custom_value(cdefs[:tar_fda_affirmation_code_1])).to eq "PFR"
        expect(t.custom_value(cdefs[:tar_fda_affirmation_qualifier_1])).to eq "511992000"
        expect(t.custom_value(cdefs[:tar_fda_affirmation_code_2])).to eq "AIN"
        expect(t.custom_value(cdefs[:tar_fda_affirmation_qualifier_2])).to eq "594799"

        expect(t.custom_value(cdefs[:tar_lacey_common_name_1])).to eq "Common"
        expect(t.custom_value(cdefs[:tar_lacey_species_1])).to eq "Species"
        expect(t.custom_value(cdefs[:tar_lacey_genus_1])).to eq "Genus"
        expect(t.custom_value(cdefs[:tar_lacey_country_1])).to eq "CN"
        expect(t.custom_value(cdefs[:tar_lacey_quantity_1])).to eq 1
        expect(t.custom_value(cdefs[:tar_lacey_uom_1])).to eq "KG"
        expect(t.custom_value(cdefs[:tar_lacey_recycled_1])).to eq 25

        expect(t.custom_value(cdefs[:tar_fws_genus_1])).to eq "GENUS"
        expect(t.custom_value(cdefs[:tar_fws_species_1])).to eq "SPECIES"
        expect(t.custom_value(cdefs[:tar_fws_general_name_1])).to eq "GENERAL"
        expect(t.custom_value(cdefs[:tar_fws_cost_1])).to eq 50.5
        expect(t.custom_value(cdefs[:tar_fws_country_origin_1])).to eq "CN"
        expect(t.custom_value(cdefs[:tar_fws_description_1])).to eq "DESC"
        expect(t.custom_value(cdefs[:tar_fws_description_code_1])).to eq "ABC"
        expect(t.custom_value(cdefs[:tar_fws_source_code_1])).to eq "W"

        expect(p.variants.length).to eq 2

        v = p.variants.first
        expect(v.variant_identifier).to eq "032020518"
        expect(v.custom_value(cdefs[:var_hts_line])).to eq 1
        expect(v.custom_value(cdefs[:var_quantity])).to eq 5
        expect(v.custom_value(cdefs[:var_lacey_species])).to eq "Species"
        expect(v.custom_value(cdefs[:var_lacey_country_harvest])).to eq "CN"

        v = p.variants.second
        expect(v.variant_identifier).to eq "032020514"
        expect(v.custom_value(cdefs[:var_hts_line])).to eq 3
        expect(v.custom_value(cdefs[:var_quantity])).to eq 4
        expect(v.custom_value(cdefs[:var_lacey_species])).to eq "Species"
        expect(v.custom_value(cdefs[:var_lacey_country_harvest])).to eq "CN"
      end

      it "removes any unreferenced 'lines' from existing parts" do
        p = existing_product

        c = p.classifications.create! country: us
        t = c.tariff_records.create! line_number: 1, hts_1: "1234567890"
        t.update_custom_value! cdefs[:tar_external_line_number], 1
        t3 = c.tariff_records.create! line_number: 5, hts_1: "1901238901"
        t3.update_custom_value! cdefs[:tar_external_line_number], 5

        uc t, :tar_add_case, "ADD123"
        uc t, :tar_cvd_case, "CVD123"
        uc t, :tar_dot_box_number, "BOX"
        uc t, :tar_fda_product_code, "CODE"
        uc t, :tar_fda_cargo_status, "STAT"
        uc t, :tar_fda_food, false

        uc t, :tar_fda_affirmation_code_7, "AFF"
        uc t, :tar_fda_affirmation_qualifier_7, "QUAL"

        uc t, :tar_lacey_common_name_10, "COM"
        uc t, :tar_lacey_genus_10, "GENUS"
        uc t, :tar_lacey_species_10, "SPECIES"
        uc t, :tar_lacey_country_10, "COO"
        uc t, :tar_lacey_quantity_10, 100
        uc t, :tar_lacey_uom_10, "UOM"
        uc t, :tar_lacey_recycled_10, 5

        uc t, :tar_fws_genus_5, "GENUS"
        uc t, :tar_fws_country_origin_5, "COO"
        uc t, :tar_fws_species_5, "SPECIES"
        uc t, :tar_fws_general_name_5, "GENERAL"
        uc t, :tar_fws_cost_5, 5
        uc t, :tar_fws_description_5, "DESC"
        uc t, :tar_fws_description_code_5, "COD"
        uc t, :tar_fws_source_code_5, "WILD"

        v = p.variants.create! variant_identifier: "12345"

        # All of this stuff shoudl get cleared off hts line 1
        subject.process_part_lines csv_data, Time.zone.now, user

        # Just reload the tariff and then all the cdefs should be nil,
        # since the second tariff line should hold them all
        expect(t).to exist_in_db
        t.reload

        # It should clear line # 3, since it's not referenced in the csv
        expect(t3).not_to exist_in_db

        expect(t.custom_value(cdefs[:tar_add_case])).to be_nil
        expect(t.custom_value(cdefs[:tar_cvd_case])).to be_nil
        expect(t.custom_value(cdefs[:tar_dot_box_number])).to be_nil
        expect(t.custom_value(cdefs[:tar_fda_product_code])).to be_nil
        expect(t.custom_value(cdefs[:tar_fda_cargo_status])).to be_nil
        expect(t.custom_value(cdefs[:tar_fda_food])).to be_nil

        expect(t.custom_value(cdefs[:tar_fda_affirmation_code_7])).to be_nil
        expect(t.custom_value(cdefs[:tar_fda_affirmation_qualifier_7])).to be_nil

        expect(t.custom_value(cdefs[:tar_lacey_common_name_10])).to be_nil
        expect(t.custom_value(cdefs[:tar_lacey_genus_10])).to be_nil
        expect(t.custom_value(cdefs[:tar_lacey_species_10])).to be_nil
        expect(t.custom_value(cdefs[:tar_lacey_country_10])).to be_nil
        expect(t.custom_value(cdefs[:tar_lacey_quantity_10])).to be_nil
        expect(t.custom_value(cdefs[:tar_lacey_uom_10])).to be_nil
        expect(t.custom_value(cdefs[:tar_lacey_recycled_10])).to be_nil

        expect(t.custom_value(cdefs[:tar_fws_genus_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_country_origin_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_species_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_general_name_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_cost_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_description_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_description_code_5])).to be_nil
        expect(t.custom_value(cdefs[:tar_fws_source_code_5])).to be_nil

        expect(v).not_to exist_in_db
      end
    end
  end

  describe "parse" do
    let(:file_data) { IO.read 'spec/fixtures/files/target_multi_part_file.csv' }

    it "reads parts from file and processes them individually" do
      first_rows = [["PHDR", "U", "US", "04", nil, "P", "013022712", "0", "197312202", "A", "Standard", "00558390",
                      nil, "UT BUTTON DO XSM FRESH WHITE V2 (UV", "Item Type - Button down shirts ABN Size", nil,
                      nil, nil, nil, nil, "0.0000", nil, nil, nil, nil, nil, " ", nil, nil, "Y", "N", "Y", "N", "N",
                      "0.0000", "N", "0.0000", nil]]
      second_rows = [["PHDR", "U", "US", "04", nil, "P", "013022712", "0", "197312202", "A", "Standard", "00558390",
                      nil, "UT BUTTON DO XSM FRESH WHITE V2 (UV", "Item Type - Button down shirts ABN Size", nil, nil,
                      nil, nil, nil, "0.0000", nil, nil, nil, nil, nil, " ", nil, nil, "Y", "N", "Y", "N", "N", "0.0000",
                      "N", "0.0000", nil]]

      expect(subject).to receive(:process_part_lines).with(first_rows, Time.zone.parse("2020-03-04 22:14:07"), User.integration)
      expect(subject).to receive(:process_part_lines).with(second_rows, Time.zone.parse("2020-03-04 22:14:07"), User.integration)

      subject.parse file_data
    end
  end
end
