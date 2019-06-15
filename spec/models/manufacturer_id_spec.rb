describe ManufacturerId do

  describe "load_mid_records" do
    subject { described_class }

    it "creates new mids" do
      row = ["MID", "Name", "Address 1", "Address 2", "City", "Postal", "US", " "]
      subject.load_mid_records [row]

      mid = ManufacturerId.where(mid: "MID").first
      expect(mid).not_to be_nil
      expect(mid.name).to eq "Name"
      expect(mid.address_1).to eq "Address 1"
      expect(mid.address_2).to eq "Address 2"
      expect(mid.city).to eq "City"
      expect(mid.postal_code).to eq "Postal"
      expect(mid.country).to eq "US"
      expect(mid.active).to eq true
    end

    it "updates existing MIDs" do
      mid = ManufacturerId.create! mid: "MID"

      row = ["MID", "Name", "Address 1", "Address 2", "City", "Postal", "US", "Y"]
      subject.load_mid_records [row]

      mid.reload

      expect(mid.name).to eq "Name"
      expect(mid.address_1).to eq "Address 1"
      expect(mid.address_2).to eq "Address 2"
      expect(mid.city).to eq "City"
      expect(mid.postal_code).to eq "Postal"
      expect(mid.country).to eq "US"
      expect(mid.active).to eq true
    end

    it "disables MID if last column is N" do
      mid = ManufacturerId.create! mid: "MID"

      row = ["MID", "Name", "Address 1", "Address 2", "City", "Postal", "US", "N"]
      subject.load_mid_records [row]

      mid.reload
      expect(mid.active).to eq false
    end
  end
end
