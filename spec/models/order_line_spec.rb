describe OrderLine do
  describe "variant validation" do
    it "should validate variant" do
      ol = OrderLine.new
      expect_any_instance_of(OpenChain::Validator::VariantLineIntegrityValidator).to receive(:validate).with(ol)
      ol.save
    end
  end
  describe "total_cost" do
    it "should multiply" do
      expect(OrderLine.new(price_per_unit:7,quantity:4).total_cost).to eq 28
    end
    it "should handle nil price per unit" do
      expect(OrderLine.new(price_per_unit:nil,quantity:4).total_cost).to eq 0
    end
    it "should handle nil quantity" do
      expect(OrderLine.new(price_per_unit:7,quantity:nil).total_cost).to eq 0
    end
  end
  describe "shipped_qty" do
    it "should get quantity from piece sets linked to shipment lines" do
      ol = OrderLine.new
      ol.piece_sets.build(shipment_line_id:1,quantity:3)
      ol.piece_sets.build(shipment_line_id:2,quantity:2)
      ol.piece_sets.build(quantity:7)
      expect(ol.shipped_qty).to eq 5
    end
  end

  describe "received_qty" do
    it "should get quantity from piece_sets linked to shipment lines with delivered date not null" do

      ol = OrderLine.new

      #find this one
      ps = ol.piece_sets.build(quantity:3)
      s = Shipment.new
      s.delivered_date = 1.day.ago
      sl = s.shipment_lines.build
      ps.shipment_line = sl

      #don't find this one because no delivered date
      ps2 = ol.piece_sets.build(quantity:2)
      s2 = Shipment.new
      sl2 = s2.shipment_lines.build
      ps2.shipment_line = sl2

      #don't find this one because no shipment line
      ol.piece_sets.build(quantity:7)

      expect(ol.received_qty).to eq 3
    end
  end

  describe "booked?" do

    it "returns true if there are booking lines associated with the order line" do
      l = OrderLine.new
      l.booking_lines << BookingLine.new

      expect(l.booked?).to eq true
    end

    it "returns false if there are no booking lines associated" do
      expect(OrderLine.new.booked?).to eq false
    end
  end

  describe "booked_qty" do
    it "returns booked quantity sum if there are booking lines associated with the order line" do
      l = OrderLine.new
      l.booking_lines << BookingLine.new(quantity: 10)
      l.booking_lines << BookingLine.new(quantity: 15)

      expect(l.booked_qty).to eq 25
    end

    it "returns zero if no booking lines" do
      expect(OrderLine.new.booked_qty).to eq 0
    end

    it "handles missing quantities" do
      l = OrderLine.new
      l.booking_lines << BookingLine.new(quantity: 10)
      l.booking_lines << BookingLine.new

      expect(l.booked_qty).to eq 10
    end
  end

  describe "can_be_deleted?" do
    it "allows deletion if line is not booked or shipped" do
      expect(subject).to receive(:booked?).and_return false
      expect(subject).to receive(:shipping?).and_return false

      expect(subject.can_be_deleted?).to eq true
    end

    it "does not allow deletion if line is booked" do
      expect(subject).to receive(:booked?).and_return true
      allow(subject).to receive(:shipping?).and_return false

      expect(subject.can_be_deleted?).to eq false
    end

    it "does not allow deletion if line is shipped" do
      allow(subject).to receive(:booked?).and_return false
      expect(subject).to receive(:shipping?).and_return true

      expect(subject.can_be_deleted?).to eq false
    end    
  end
end
