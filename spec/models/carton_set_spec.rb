describe CartonSet do
  describe "total_gross_kgs" do
    it "figures out the gross kgs" do
      cs = CartonSet.new carton_qty: 10, gross_kgs: BigDecimal("25.50")
      expect(cs.total_gross_kgs).to eq BigDecimal("255.0")
    end

    it "returns 0 if carton_qty is missing" do
      cs = CartonSet.new gross_kgs: BigDecimal("25.50")
      expect(cs.total_gross_kgs).to eq BigDecimal("0")
    end

    it "returns 0 if gross weight is missing" do
      cs = CartonSet.new carton_qty: 10
      expect(cs.total_gross_kgs).to eq BigDecimal("0")
    end
  end

  describe "total_volume_cbms" do
    it "figures out total cubic meters for carton set" do
      cs = CartonSet.new length_cm: BigDecimal("20"), width_cm: BigDecimal("50"), height_cm: BigDecimal("100"), carton_qty: 10
      expect(cs.total_volume_cbms).to eq BigDecimal("1")
    end

    it "returns zero if length is nil" do
      cs = CartonSet.new width_cm: BigDecimal("50"), height_cm: BigDecimal("100"), carton_qty: 10
      expect(cs.total_volume_cbms).to eq 0
    end

    it "returns zero if width is nil" do
      cs = CartonSet.new length_cm: BigDecimal("50"), height_cm: BigDecimal("100"), carton_qty: 10
      expect(cs.total_volume_cbms).to eq 0
    end

    it "returns zero if height is nil" do
      cs = CartonSet.new length_cm: BigDecimal("50"), width_cm: BigDecimal("100"), carton_qty: 10
      expect(cs.total_volume_cbms).to eq 0
    end

    it "returns zero if qty is nil" do
      cs = CartonSet.new length_cm: BigDecimal("50"), width_cm: BigDecimal("100"), height_cm: BigDecimal("100")
      expect(cs.total_volume_cbms).to eq 0
    end

    it "rounds result to 2 decimal places by default" do
      cs = CartonSet.new length_cm: BigDecimal("20.5"), width_cm: BigDecimal("50.60"), height_cm: BigDecimal("100.11"), carton_qty: 10
      expect(cs.total_volume_cbms(2)).to eq BigDecimal("1.04")
    end

    it "rounds result to the given number of decimal places" do
      cs = CartonSet.new length_cm: BigDecimal("20.5"), width_cm: BigDecimal("50.60"), height_cm: BigDecimal("100.11"), carton_qty: 10
      expect(cs.total_volume_cbms(5)).to eq BigDecimal("1.03844")
    end
  end
end
