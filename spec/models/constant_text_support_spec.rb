describe ConstantTextSupport do

  describe "constant_text_for_date" do
    let (:object) {
      p = Product.new
      p.constant_texts.build text_type: "TYPE1", effective_date_start: Date.new(2018, 1, 1), constant_text: "TEXT 1"
      p.constant_texts.build text_type: "TYPE1", effective_date_start: Date.new(2018, 2, 1), constant_text: "TEXT 2"
      p.constant_texts.build text_type: "TYPE1", effective_date_start: Date.new(2018, 3, 1), constant_text: "TEXT 3"

      p
    }

    it "returns best matching text" do
      expect(object.constant_text_for_date("TYPE1").try(:constant_text)).to eq "TEXT 3"
    end

    it "excludes texts that have expired" do
      object.constant_texts.last.effective_date_end = Date.new(2018, 3, 2)
      expect(object.constant_text_for_date("TYPE1").try(:constant_text)).to eq "TEXT 2"
    end

    it "allows passing custom reference date" do
      expect(object.constant_text_for_date("TYPE1", reference_date: Date.new(2018, 1, 2)).try(:constant_text)).to eq "TEXT 1"
    end

    it "returns nil if no text match" do
      expect(object.constant_text_for_date("TYPE1", reference_date: Date.new(2017, 1, 1))).to be_nil
    end

    it "handles nil dates" do
      expect(object.constant_text_for_date("TYPE1", reference_date: nil)).to be_nil
    end
  end
end