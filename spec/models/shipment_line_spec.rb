describe ShipmentLine do
  describe "variant validation" do
    it "should validate variant" do
      sl = ShipmentLine.new
      expect_any_instance_of(OpenChain::Validator::VariantLineIntegrityValidator).to receive(:validate).with(sl)
      sl.save
    end
  end
  describe "locked?" do
    it "should lock if shipment is locked" do
      s = Shipment.new
      allow(s).to receive(:locked?).and_return(true)
      line = ShipmentLine.new(:shipment=>s)
      expect(line).to be_locked
    end
    it "should lock if on commercial invoice" do
      s_line = create(:shipment_line)
      c_line = create(:commercial_invoice_line)
      PieceSet.create!(:shipment_line_id=>s_line.id, :commercial_invoice_line_id=>c_line.id, :quantity=>1)
      s_line.reload
      expect(s_line).to be_locked
    end
    it "shouldn't be locked by default" do
      expect(ShipmentLine.new).not_to be_locked
    end
  end
  describe "merge_piece_sets" do
    it "should merge piece sets on destroy" do
      ol = create(:order_line)
      sl = create(:shipment_line, product:ol.product)
      ps1 = PieceSet.create!(order_line_id:ol.id, quantity:7)
      ps2 = PieceSet.create!(order_line_id:ol.id, quantity:3, shipment_line_id:sl.id)
      sl.reload
      expect {sl.destroy}.to change(PieceSet, :count).from(2).to(1)
      new_ps = PieceSet.first
      expect(new_ps.quantity).to eq 10
      expect(new_ps.order_line_id).to eq ol.id
      expect(new_ps.shipment_line_id).to be_nil
    end
  end

  describe "order_line" do
    let (:order_line) { create(:order_line) }

    let (:shipment_line) {
      s = create(:shipment_line, product: order_line.product, linked_order_line_id: order_line.id)
    }

    it "finds and caches order line lookup" do
      expect(shipment_line.order_line).to eq order_line

      # The easiest way to show that the lookup is cached is by deleting order line and then calling the method again
      # and seeing if it still returns order line
      order_line.destroy
      expect(shipment_line.order_line).to eq order_line
    end

    it "resets cache after update" do
      line_number = order_line.line_number
      expect(shipment_line.order_line).to eq order_line
      # If we update the order line under the covers, the cached version shouldn't change
      order_line.update_attributes! line_number: (line_number + 100)
      expect(shipment_line.order_line.line_number).to eq line_number

      # A save will invalidate the cache and the next call to order_line will reload it
      shipment_line.save!
      expect(shipment_line.order_line.line_number).to eq (line_number + 100)
    end
  end

  describe "dimensional_weight" do

    subject { ShipmentLine.new cbms: BigDecimal("1") }

    it "multiplies volume by 0.006 and rounds to 2 digits" do
      expect(subject.dimensional_weight).to eq BigDecimal("166.67")
    end

    it "handles nil volume" do
      subject.cbms = nil
      expect(subject.dimensional_weight).to eq nil
    end
  end

  describe "chargeable_weight" do

    subject { ShipmentLine.new cbms: BigDecimal("1"), gross_kgs: BigDecimal("160") }

    it "uses dimensional_weight if it's more than gross weight" do
      expect(subject.chargeable_weight).to eq BigDecimal("166.67")
    end

    it "uses gross weight if it's more than dimensional weight" do
      subject.gross_kgs = BigDecimal("166.68")
      expect(subject.chargeable_weight).to eq BigDecimal("166.68")
    end

    it "handles nil dimensional_weight" do
      subject.cbms = nil
      expect(subject.chargeable_weight).to eq BigDecimal("160")
    end

    it "handles nil gross weight" do
      subject.gross_kgs = nil
      expect(subject.chargeable_weight).to eq BigDecimal("166.67")
    end

    it "handles nil weights" do
      subject.cbms = nil
      subject.gross_kgs = nil
      expect(subject.chargeable_weight).to eq nil
    end
  end
end
