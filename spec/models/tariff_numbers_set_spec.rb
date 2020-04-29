describe TariffNumberSet do

  describe "include?" do

    it "matches full length tariffs" do
      subject << "1234567890"
      expect(subject.include? "1234567890").to eq true
    end

    it "matches partial tariffs" do
      subject << "1234"

      expect(subject.include? "1234567890").to eq true
    end

    it "does not match on less than 2 digits" do
      subject << "1"

      expect(subject.include? "1234567890").to eq false
    end

    it "returns false if the tariff is not in the set" do
      subject << "12"

      expect(subject.include? "2312121212").to eq false
    end
  end

  describe "find" do
    it "matches full length tariffs" do
      subject << "1234567890"
      expect(subject.find "1234567890").to eq "1234567890"
    end

    it "matches partial tariffs" do
      subject << "1234"
      expect(subject.find "1234567890").to eq "1234"
    end

    it "does not match on less than 2 digits" do
      subject << "1"

      expect(subject.find "1234567890").to be_nil
    end

    it "returns nil if the tariff is not in the set" do
      subject << "12"

      expect(subject.find "2312121212").to be_nil
    end

    it "returns the most specific match" do
      subject << "12"
      subject << "1234"
      expect(subject.find "1234567890").to eq "1234"
    end
  end

  describe "add" do
    it "adds a tariff number" do
      subject.add "12"
      expect(subject.include? "12").to eq true
    end

    it "adds a more specific value" do
      subject.add "12"
      subject.add "1234"
      expect(subject.to_a).to eq ["12", "1234"]
    end

    it "strips periods from number" do
      subject.add("1234.56")
      expect(subject.to_a).to eq ["123456"]
    end

    it "validates number is not null" do
      expect { subject.add nil }.to raise_error ArgumentError, "Tariff Number cannot be nil."
    end

    it "validates number is a valid tariff number" do
      expect { subject.add "!"}.to raise_error ArgumentError, "Invalid Tariff Number '!'."
    end
  end

  describe "add?" do

    # Since add? utilizes the add method under the covers, this describe solely tests the
    # specifics of the add? (that it returns self if the value was actually added)
    it "adds a tariff number" do
      expect(subject.add? "12").to eq subject
    end

    it "adds a more specific tariff value" do
      subject.add? "12"
      expect(subject.add? "1234").to eq subject
    end

    it "returns nil if value wasn't actually added" do
      subject.add? "12"
      expect(subject.add? "12").to be_nil
    end
  end
end