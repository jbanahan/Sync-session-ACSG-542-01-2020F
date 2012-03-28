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
end
