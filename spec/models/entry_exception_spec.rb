describe EntryException do
  describe "resolved?" do
    it "determines exception to be resolved if resolved date has value" do
      expect(described_class.new(resolved_date: Date.new(2020, 5, 5)).resolved?).to eq true
      expect(described_class.new(resolved_date: nil).resolved?).to eq false
    end
  end
end
