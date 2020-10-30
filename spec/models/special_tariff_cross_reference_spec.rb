describe SpecialTariffCrossReference do

  describe "before_validation / clean_hts" do
    it "strips non-hts chars from attribute on validation" do
      hts = described_class.new hts_number: "1234.56.7890", special_hts_number: "0987.65.4321"
      hts.valid?
      expect(hts.hts_number).to eq "1234567890"
      expect(hts.special_hts_number).to eq "0987654321"
    end
  end

  describe SpecialTariffCrossReference::SpecialTariffHash do

    before do
      subject.insert SpecialTariffCrossReference.new(hts_number: "1234567890", special_hts_number: "0987654321", created_at: Time.zone.now)
      subject.insert SpecialTariffCrossReference.new(hts_number: "1234567", special_hts_number: "987654", created_at: (Time.zone.now + 1.minute))
    end

    describe "[]" do
      it "returns a matching special tariff" do
        refs = subject["1234567890"]
        expect(refs.length).to eq 1
        expect(refs.first.special_hts_number).to eq "0987654321"
      end

      it "finds best matching special tariff" do
        refs = subject["1234567000"]
        expect(refs.length).to eq 1
        expect(refs.first.special_hts_number).to eq "987654"
      end

      it "returns multiple tariffs if they have different tariff types" do
        subject.insert(SpecialTariffCrossReference.new(hts_number: "1234567890", special_hts_number: "5678901234",
                                                       special_tariff_type: "TYPE", created_at: (Time.zone.now + 2.minutes)))

        refs = subject["1234567890"]
        expect(refs.length).to eq 2
        expect(refs.map(&:special_hts_number)).to eq ["0987654321", "5678901234"]
      end
    end
  end

  describe SpecialTariffCrossReference::SpecialTariffHashResult do

    let (:tariff_1) { SpecialTariffCrossReference.new(hts_number: "1234567890", special_hts_number: "0987654321", created_at: Time.zone.now, country_origin_iso: "CN") }
    let (:tariff_2) { SpecialTariffCrossReference.new(hts_number: "1234567", special_hts_number: "987654", created_at: (Time.zone.now + 1.minute), priority: 1) }

    before do
      subject.insert tariff_1
      subject.insert tariff_2
    end

    describe "size" do
      it "returns the number of tariffs inserted" do
        expect(subject.size).to eq 2
      end
    end

    describe "tariffs_for" do
      it "returns sorted tariffs for a given country origin, hts" do
        tariffs = subject.tariffs_for "CN", "1234567890"
        expect(tariffs.length).to eq 2
        expect(tariffs.first).to eq tariff_2
        expect(tariffs.second).to eq tariff_1
      end

      it "does not duplicate tariff if no country is given" do
        tariffs = subject.tariffs_for nil, "1234567890"
        expect(tariffs.length).to eq 1
        expect(tariffs.first).to eq tariff_2
      end

      it "handles any casing and removes spaces" do
        tariffs = subject.tariffs_for " Cn ", "1234567890"
        expect(tariffs.length).to eq 2
      end

      it "finds best matching special tariff" do
        refs = subject.tariffs_for "CN", "1234567000"
        expect(refs.length).to eq 1
        expect(refs.first.special_hts_number).to eq "987654"
      end

      it "returns multiple tariffs if they have different tariff types" do
        subject.insert(SpecialTariffCrossReference.new(hts_number: "1234567890", special_hts_number: "5678901234",
                                                       special_tariff_type: "TYPE", created_at: (Time.zone.now + 2.minutes)))

        refs = subject.tariffs_for "CN", "1234567890"
        expect(refs.length).to eq 3
        expect(refs.map(&:special_hts_number)).to eq ["987654", "0987654321", "5678901234"]
      end
    end

  end

  describe "find_special_tariff_hash" do
    subject { described_class }

    let!(:special_tariff) do
      described_class.create!(hts_number: "12345678", import_country_iso: "US", country_origin_iso: "CN",
                              special_hts_number: "0987654321", effective_date_start: Date.new(2018, 7, 9),
                              effective_date_end: Date.new(2018, 8, 1))
    end

    it "returns all special tariffs with effective dates after given date" do
      result = subject.find_special_tariff_hash "US", true, reference_date: Date.new(2018, 7, 9)
      expect(result.size).to eq 1
      expect(result).to be_a SpecialTariffCrossReference::SpecialTariffHashResult
      expect(result.tariffs_for("CN", "1234567890")).to eq [special_tariff]
    end

    it "excludes tariffs with start date after reference date" do
      result = subject.find_special_tariff_hash "US", true, reference_date: Date.new(2018, 7, 1)
      expect(result.size).to eq 0
    end

    it "excludes tariffs with end date prior to reference date" do
      result = subject.find_special_tariff_hash "US", true, reference_date: Date.new(2018, 8, 9)
      expect(result.size).to eq 0
    end

    it "excludes tariffs not for given country of origin" do
      result = subject.find_special_tariff_hash "US", true, reference_date: Date.new(2018, 7, 9), country_origin_iso: "US"
      expect(result.size).to eq 0
    end

    it "excludes tariffs not for given import country" do
      result = subject.find_special_tariff_hash "CA", true, reference_date: Date.new(2018, 7, 9)
      expect(result.size).to eq 0
    end

    it "excludes suppressed tariffs" do
      special_tariff.update! suppress_from_feeds: true
      result = subject.find_special_tariff_hash "US", true, reference_date: Date.new(2018, 7, 9)
      expect(result.size).to eq 0
    end

    it "includes suppressed if instructed to" do
      special_tariff.update! suppress_from_feeds: true

      result = subject.find_special_tariff_hash "US", false, reference_date: Date.new(2018, 7, 9)
      expect(result.size).to eq 1
    end

    it "allows using special tariffs as hash keys" do
      result = subject.find_special_tariff_hash "US", false, reference_date: Date.new(2018, 7, 9), use_special_number_as_key: true
      expect(result.size).to eq 1
      expect(result.tariffs_for("CN", "0987654321")).to eq [special_tariff]
    end
  end

  describe "parse" do
    subject { described_class }

    let (:data_row) do
      ["301 Tariffs", "US", "1234567890", "0987654321", "CO", "2018-09-21", "2018-09-22"]
    end

    let (:csv) do
      data_row.to_csv
    end

    let (:io) do
      StringIO.new csv
    end

    it "loads required tariff data" do
      expect { subject.parse io }.to change(described_class, :count).from(0).to(1)

      ref = described_class.first
      expect(ref.hts_number).to eq "1234567890"
      expect(ref.special_hts_number).to eq "0987654321"
      expect(ref.country_origin_iso).to eq "CO"
      expect(ref.effective_date_start).to eq Date.new(2018, 9, 21)
      expect(ref.effective_date_end).to eq Date.new(2018, 9, 22)
      expect(ref.special_tariff_type).to eq "301 Tariffs"
      expect(ref.priority).to eq nil
      expect(ref.suppress_from_feeds).to eq false
    end

    it "loads all tariff data" do
      data_row << "10" << "true"
      expect { subject.parse io }.to change(described_class, :count).from(0).to(1)

      ref = described_class.first
      expect(ref.hts_number).to eq "1234567890"
      expect(ref.special_hts_number).to eq "0987654321"
      expect(ref.country_origin_iso).to eq "CO"
      expect(ref.effective_date_start).to eq Date.new(2018, 9, 21)
      expect(ref.effective_date_end).to eq Date.new(2018, 9, 22)
      expect(ref.special_tariff_type).to eq "301 Tariffs"
      expect(ref.priority).to eq 10
      expect(ref.suppress_from_feeds).to eq true
    end

    it "updates an existing record" do
      ref = described_class.create!(import_country_iso: "US", hts_number: "1234567890", special_hts_number: "0987654321",
                                    country_origin_iso: "CO", effective_date_start: Date.new(2018, 9, 21), special_tariff_type: "301 Tariffs")
      subject.parse io

      ref.reload

      expect(ref.hts_number).to eq "1234567890"
      expect(ref.special_hts_number).to eq "0987654321"
      expect(ref.country_origin_iso).to eq "CO"
      expect(ref.effective_date_start).to eq Date.new(2018, 9, 21)
      expect(ref.effective_date_end).to eq Date.new(2018, 9, 22)
    end

    it "skips lines with missing import country iso" do
      data_row[0] = ""
      expect { subject.parse io }.not_to change(described_class, :count).from(0)
    end

    it "skips lines with missing tariff type" do
      data_row[1] = ""
      expect { subject.parse io }.not_to change(described_class, :count).from(0)
    end

    it "skips lines with missing hts" do
      data_row[2] = ""
      expect { subject.parse io }.not_to change(described_class, :count).from(0)
    end

    it "skips lines with invalid hts" do
      data_row[2] = "invalid"
      expect { subject.parse io }.not_to change(described_class, :count).from(0)
    end

    it "skips lines with missing special hts" do
      data_row[3] = ""
      expect { subject.parse io }.not_to change(described_class, :count).from(0)
    end

    it "skips lines with invalid special hts" do
      data_row[3] = "invalid"
      expect { subject.parse io }.not_to change(described_class, :count).from(0)
    end
  end
end
