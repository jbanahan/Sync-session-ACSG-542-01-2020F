require 'spec_helper'

describe ShipmentLine do
  describe "locked?" do
    it "should lock if shipment is locked" do
      s = Shipment.new
      s.stub(:locked?).and_return(true)
      line = ShipmentLine.new(:shipment=>s)
      line.should be_locked
    end
    it "should lock if on commercial invoice" do
      s_line = Factory(:shipment_line)
      c_line = Factory(:commercial_invoice_line)
      PieceSet.create!(:shipment_line_id=>s_line.id,:commercial_invoice_line_id=>c_line.id,:quantity=>1)
      s_line.reload
      s_line.should be_locked
    end
    it "shouldn't be locked by default" do
      ShipmentLine.new.should_not be_locked
    end
  end
  describe :merge_piece_sets do
    it "should merge piece sets on destroy" do
      ol = Factory(:order_line)
      sl = Factory(:shipment_line,product:ol.product)
      ps1 = PieceSet.create!(order_line_id:ol.id,quantity:7)
      ps2 = PieceSet.create!(order_line_id:ol.id,quantity:3,shipment_line_id:sl.id)
      sl.reload
      expect {sl.destroy}.to change(PieceSet,:count).from(2).to(1)
      new_ps = PieceSet.first 
      expect(new_ps.quantity).to eq 10
      expect(new_ps.order_line_id).to eq ol.id
      expect(new_ps.shipment_line_id).to be_nil
    end
  end
end
