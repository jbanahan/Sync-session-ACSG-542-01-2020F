describe OpenChain::CustomHandler::Target::TargetCustomsManagementProductGenerator do

  describe "build_data" do
    let (:us) { Factory(:country, iso_code: "US") }
    let (:cdefs) { subject.send(:cdefs) }
    let (:product) do
      p = Factory(:product, unique_identifier: "12345-67", name: "DESCRIPTION")
      p.update_custom_value! cdefs[:prod_tsca], true

      c = p.classifications.create! country: us
      t1 = c.tariff_records.create! line_number: 1, hts_1: "9903123456", hts_2: "1234567890", hts_3: "9876543210"
      t2 = c.tariff_records.create! line_number: 2, hts_1: "6789012345"

      t1.update_custom_value!(cdefs[:tar_add_case], "ADDCASE")
      t1.update_custom_value!(cdefs[:tar_cvd_case], "CVDCASE")
      t1.update_custom_value!(cdefs[:tar_spi_primary], "SP")
      t1.update_custom_value!(cdefs[:tar_xvv], "X")
      t1.update_custom_value!(cdefs[:tar_component_description], "COMPONENT DESC")
      t1.update_custom_value!(cdefs[:tar_country_of_origin], "US")

      t1.update_custom_value!(cdefs[:tar_fda_product_code], "FDACODE")
      t1.update_custom_value!(cdefs[:tar_fda_cargo_status], "F")
      t1.update_custom_value!(cdefs[:tar_fda_affirmation_code_1], "AFFC1")
      t1.update_custom_value!(cdefs[:tar_fda_affirmation_qualifier_1], "AFFQ1")
      t1.update_custom_value!(cdefs[:tar_fda_affirmation_code_2], "AFFC2")

      t1.update_custom_value!(cdefs[:tar_dot_box_number], "2A")
      t1.update_custom_value!(cdefs[:tar_dot_program], "REI")

      t1.update_custom_value!(cdefs[:tar_lacey_common_name_1], "Atlas cedar")
      t1.update_custom_value!(cdefs[:tar_lacey_genus_1], "Cedrus")
      t1.update_custom_value!(cdefs[:tar_lacey_species_1], "Atlantica")
      t1.update_custom_value!(cdefs[:tar_lacey_country_1], "CA")
      t1.update_custom_value!(cdefs[:tar_lacey_quantity_1], 1)
      t1.update_custom_value!(cdefs[:tar_lacey_uom_1], "EA")
      t1.update_custom_value!(cdefs[:tar_lacey_recycled_1], 25)

      t1.update_custom_value!(cdefs[:tar_fws_general_name_1], "Narwhal")
      t1.update_custom_value!(cdefs[:tar_fws_genus_1], "Monodon")
      t1.update_custom_value!(cdefs[:tar_fws_species_1], "Monoceros")
      t1.update_custom_value!(cdefs[:tar_fws_country_origin_1], "CA")
      t1.update_custom_value!(cdefs[:tar_fws_cost_1], 100)
      t1.update_custom_value!(cdefs[:tar_fws_description_1], "Wild Narwhal")
      t1.update_custom_value!(cdefs[:tar_fws_description_code_1], "WN")
      t1.update_custom_value!(cdefs[:tar_fws_source_code_1], "W")

      t1.update_custom_value!(cdefs[:tar_fda_flag], true)
      t1.update_custom_value!(cdefs[:tar_dot_flag], false)
      t1.update_custom_value!(cdefs[:tar_fws_flag], true)
      t1.update_custom_value!(cdefs[:tar_lacey_flag], false)

      t2.update_custom_value!(cdefs[:tar_country_of_origin], "CA")

      p
    end

    it "builds ProductData" do
      d = subject.build_data product

      expect(d.customer_number).to eq "TARGEN"
      expect(d.part_number).to eq "12345-67"
      expect(d.effective_date).to eq Date.new(2014, 1, 1)
      expect(d.expiration_date).to eq Date.new(2099, 12, 31)
      expect(d.country_of_origin).to eq "US"
      expect(d.tsca_certification).to eq "C"

      expect(d.penalty_data.length).to eq 2

      p = d.penalty_data.first
      expect(p.penalty_type).to eq "ADA"
      expect(p.case_number).to eq "ADDCASE"

      p = d.penalty_data.second
      expect(p.penalty_type).to eq "CVD"
      expect(p.case_number).to eq "CVDCASE"

      expect(d.tariff_data.length).to eq 4

      t = d.tariff_data.first
      expect(t.primary_tariff).to be_nil
      expect(t.tariff_number).to eq "9903123456"
      expect(t.spi).to be_nil
      expect(t.spi2).to be_nil
      expect(t.description).to be_nil
      expect(t.fda_data).to be_nil
      expect(t.lacey_data).to be_nil
      expect(t.dot_data).to be_nil
      expect(t.fish_wildlife_data).to be_nil

      t = d.tariff_data.second
      expect(t.primary_tariff).to eq true
      expect(t.tariff_number).to eq "1234567890"
      expect(t.spi).to eq "SP"
      expect(t.spi2).to eq "X"
      expect(t.description).to eq "COMPONENT DESC"
      expect(t.description_date).to eq(
        product.classifications.first.tariff_records.first.find_custom_value(cdefs[:tar_component_description]).created_at.in_time_zone("America/New_York")
      )
      expect(t.fda_data.length).to eq 1
      expect(t.lacey_data.length).to eq 1
      expect(t.dot_data.length).to eq 1
      expect(t.fish_wildlife_data.length).to eq 1

      fda = t.fda_data.first
      expect(fda.product_code).to eq "FDACODE"
      expect(fda.cargo_storage_status).to eq "F"
      expect(fda.affirmations_of_compliance.length).to eq 2

      a = fda.affirmations_of_compliance.first
      expect(a.code).to eq "AFFC1"
      expect(a.qualifier).to eq "AFFQ1"

      a = fda.affirmations_of_compliance.second
      expect(a.code).to eq "AFFC2"
      expect(a.qualifier).to be_nil

      dot = t.dot_data.first
      expect(dot.nhtsa_program).to eq "REI"
      expect(dot.box_number).to eq "2A"

      lacey = t.lacey_data.first
      expect(lacey.components.length).to eq 1

      l = lacey.components.first
      expect(l.country_of_harvest).to eq "CA"
      expect(l.quantity).to eq 1
      expect(l.quantity_uom).to eq "EA"
      expect(l.percent_recycled).to eq 25
      expect(l.common_name_general).to eq "Atlas cedar"
      expect(l.scientific_names.length).to eq 1
      expect(l.scientific_names.first.genus).to eq "Cedrus"
      expect(l.scientific_names.first.species).to eq "Atlantica"

      fws = t.fish_wildlife_data.first

      expect(fws.common_name_general).to eq "Narwhal"
      expect(fws.country_where_born).to eq "CA"
      expect(fws.foreign_value).to eq 100
      expect(fws.description_code).to eq "WN"
      expect(fws.source_description).to eq "Wild Narwhal"
      expect(fws.source_code).to eq "W"
      expect(fws.scientific_name.genus).to eq "Monodon"
      expect(fws.scientific_name.species).to eq "Monoceros"

      epa = t.epa_data.first
      expect(epa.epa_code).to eq "EP7"
      expect(epa.epa_program_code).to eq "TS1"
      expect(epa.positive_certification).to be_nil

      expect(t.fda_flag).to eq true
      expect(t.dot_flag).to eq false
      expect(t.fws_flag).to eq true
      expect(t.lacey_flag).to eq false
    end

    it "strips duplicate supplemental tariffs" do
      t2 = product.classifications.first.tariff_records.second
      # by adding the 9903 number to the second tariff row, we're making sure that the generator
      # removes it, because the same number is also on the first row.
      t2.update! hts_1: "9903123456", hts_2: "6789012345"

      product.reload

      d = subject.build_data product

      expect(d.tariff_data.length).to eq 4
      expect(d.tariff_data[0].tariff_number).to eq "9903123456"
      expect(d.tariff_data[1].tariff_number).to eq "1234567890"
      expect(d.tariff_data[2].tariff_number).to eq "9876543210"
      expect(d.tariff_data[3].tariff_number).to eq "6789012345"
    end

    it "sends positive certification for EPA if TSCA Positive document type is required" do
      product.update_custom_value! cdefs[:prod_required_documents], "BLAH, BLAH, TSCA Positive"

      d = subject.build_data product
      t = d.tariff_data.second

      epa = t.epa_data.first
      expect(epa.epa_code).to eq "EP7"
      expect(epa.epa_program_code).to eq "TS1"
      expect(epa.positive_certification).to eq true
    end
  end

  describe "importer" do
    let!(:target) { with_customs_management_id(Factory(:importer), "TARGEN") }

    it "finds target account" do
      expect(subject.importer).to eq target
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    let(:importer) { Company.new }

    it "syncs_xml" do
      expect_any_instance_of(subject).to receive(:importer).and_return importer
      expect_any_instance_of(subject).to receive(:sync_xml).with(importer)

      subject.run_schedulable
    end
  end
end
