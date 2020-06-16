describe SystemDate do
  describe "find_start_date" do
    it "finds the start date with no company involvement" do
      described_class.create!(date_type: "XYZ", start_date: Date.new(2020, 2, 20), end_date: Date.new(2030, 3, 30), company_id: nil)

      expect(described_class.find_start_date("XYZ")).to eq Date.new(2020, 2, 20)
      expect(described_class.find_start_date("ABC")).to eq nil
      expect(described_class.find_start_date("XYZ", 555)).to eq nil
    end

    it "finds the start date that is tied to a specific company" do
      c = Factory(:company)
      described_class.create!(date_type: "XYZ", start_date: Date.new(2020, 2, 20), end_date: Date.new(2030, 3, 30), company_id: c.id)

      expect(described_class.find_start_date("XYZ", c)).to eq Date.new(2020, 2, 20)
      expect(described_class.find_start_date("XYZ", c.id)).to eq Date.new(2020, 2, 20)
      expect(described_class.find_start_date("ABC")).to eq nil
      expect(described_class.find_start_date("XYZ")).to eq nil
    end

    it "defaults to a date if provided" do
      expect(described_class.find_start_date("ABC")).to eq nil
      expect(described_class.find_start_date("ABC", default_date: Date.new(2020, 2, 20))).to eq Date.new(2020, 2, 20)
      expect(described_class.find_start_date("ABC", 555, default_date: Date.new(2020, 2, 20))).to eq Date.new(2020, 2, 20)
    end
  end

  describe "find_end_date" do
    it "finds the end date with no company involvement" do
      described_class.create!(date_type: "XYZ", start_date: Date.new(2020, 2, 20), end_date: Date.new(2030, 3, 30), company_id: nil)

      expect(described_class.find_end_date("XYZ")).to eq Date.new(2030, 3, 30)
      expect(described_class.find_end_date("ABC")).to eq nil
      expect(described_class.find_end_date("XYZ", 555)).to eq nil
    end

    it "finds the end date that is tied to a specific company" do
      c = Factory(:company)
      described_class.create!(date_type: "XYZ", start_date: Date.new(2020, 2, 20), end_date: Date.new(2030, 3, 30), company_id: c.id)

      expect(described_class.find_end_date("XYZ", c)).to eq Date.new(2030, 3, 30)
      expect(described_class.find_end_date("XYZ", c.id)).to eq Date.new(2030, 3, 30)
      expect(described_class.find_end_date("ABC")).to eq nil
      expect(described_class.find_end_date("XYZ")).to eq nil
    end

    it "defaults to a date if provided" do
      expect(described_class.find_end_date("ABC")).to eq nil
      expect(described_class.find_end_date("ABC", default_date: Date.new(2020, 2, 20))).to eq Date.new(2020, 2, 20)
      expect(described_class.find_end_date("ABC", 555, default_date: Date.new(2020, 2, 20))).to eq Date.new(2020, 2, 20)
    end
  end

end
