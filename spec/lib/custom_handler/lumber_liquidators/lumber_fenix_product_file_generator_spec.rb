describe OpenChain::CustomHandler::LumberLiquidators::LumberFenixProductFileGenerator do

  let (:cdefs) do
    described_class.prep_custom_definitions [:prod_part_number, :prod_country_of_origin, :class_customs_description,
                                             :class_special_program_indicator, :class_cfia_requirement_id,
                                             :class_cfia_requirement_version, :class_cfia_requirement_code,
                                             :class_ogd_end_use, :class_ogd_misc_id, :class_ogd_origin,
                                             :class_sima_code, :class_stale_classification, :prod_fta]
  end

  describe "make_file" do
    let!(:canada) { FactoryBot(:country, iso_code: 'CA') }
    let!(:prod) { FactoryBot(:product, unique_identifier: 'myuid', name: "Name Description") }
    let!(:clas) do
      c = prod.classifications.create!(country_id: canada.id)
      c.tariff_records.create!(hts_1: '1234567890')
      c
    end

    before do
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("Full Fenix Product File").and_return true
    end

    def generator code, opts = {}
      g = described_class.new(code, opts)
      allow(g).to receive(:stale_classification?).and_return false
      g
    end

    it "generates output file" do
      prod.update_custom_value! cdefs[:prod_country_of_origin], "CN"
      prod.update_custom_value! cdefs[:prod_fta], "USMCA"
      clas.update_custom_value! cdefs[:class_customs_description], "Random Product Description"
      clas.update_custom_value! cdefs[:class_special_program_indicator], "10"
      clas.update_custom_value! cdefs[:class_cfia_requirement_id], "ID"
      clas.update_custom_value! cdefs[:class_cfia_requirement_version], "VER"
      clas.update_custom_value! cdefs[:class_cfia_requirement_code], "COD"
      clas.update_custom_value! cdefs[:class_ogd_end_use], "U"
      clas.update_custom_value! cdefs[:class_ogd_misc_id], "M"
      clas.update_custom_value! cdefs[:class_ogd_origin], "O"
      clas.update_custom_value! cdefs[:class_sima_code], "S"

      generator("LUMBER").make_file([prod]) do |file, _sr|
        read = IO.read(file.path)
        expect(read[0, 15]).to eq "N".ljust(15)
        expect(read[15, 9]).to eq "LUMBER   "
        expect(read[31, 40]).to eq "myuid".ljust(40)
        expect(read[71, 20]).to eq "1234567890".ljust(20)
        expect(read[135, 50]).to eq "Random Product Description".ljust(50)
        expect(read[341, 3]).to eq "10 "
        expect(read[359, 3]).to eq "CN "
        expect(read[362, 8]).to eq "ID      "
        expect(read[370, 4]).to eq "VER "
        expect(read[374, 6]).to eq "COD   "
        expect(read[380, 3]).to eq "U  "
        expect(read[383, 3]).to eq "M  "
        expect(read[386, 3]).to eq "O  "
        expect(read[389, 2]).to eq "S "
        expect(read).to end_with "\r\n"
      end
    end

    it "includes SPI when FTA is 'USMCA', case insensitive" do
      prod.update_custom_value! cdefs[:prod_fta], "usmca"
      clas.update_custom_value! cdefs[:class_special_program_indicator], "10"

      generator("LUMBER").make_file([prod]) do |file, _sr|
        read = IO.read(file.path)
        expect(read[341, 3]).to eq "10 "
      end
    end

    it "does not include SPI when FTA is not 'USMCA'" do
      prod.update_custom_value! cdefs[:prod_fta], "YMCA"
      clas.update_custom_value! cdefs[:class_special_program_indicator], "10"

      generator("LUMBER").make_file([prod]) do |file, _sr|
        read = IO.read(file.path)
        expect(read[341, 3]).to eq "   "
      end
    end

    ["US", "us"].each do |country_iso|
      it "uses alternate country code when origin is #{country_iso}" do
        prod.update_custom_value! cdefs[:prod_country_of_origin], country_iso

        generator("LUMBER").make_file([prod]) do |file, _sr|
          read = IO.read(file.path)
          expect(read[359, 3]).to eq "UVA"
        end
      end
    end
  end

  describe "run_schedulable" do
    it "passes in all possible options when provided" do
      hash = {"fenix_customer_code" => "XYZ", "importer_id" => "23" }
      fpfg = instance_double("generator")

      expect(described_class).to receive(:new).with("XYZ", hash).and_return(fpfg)
      expect(fpfg).to receive(:generate)
      described_class.run_schedulable(hash)
    end
  end

end