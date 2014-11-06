require 'spec_helper'

describe OrderLine do
  describe :total_cost do
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
  describe :shipped_qty do
    it "should get quantity from piece sets linked to shipment lines" do
      ol = OrderLine.new
      ol.piece_sets.build(shipment_line_id:1,quantity:3)
      ol.piece_sets.build(shipment_line_id:2,quantity:2)
      ol.piece_sets.build(quantity:7)
      expect(ol.shipped_qty).to eq 5
    end
  end

  describe :received_qty do
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
end