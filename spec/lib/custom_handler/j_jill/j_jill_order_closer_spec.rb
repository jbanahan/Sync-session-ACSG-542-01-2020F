require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillOrderCloser do
  describe :close? do
    it "should close an order > 60 days after ship_window_end" do
      o = Order.new(ship_window_end:61.days.ago)
      expect(described_class.new.close?(o)).to be_truthy
    end
    it "should close an order 95%+ shipped" do
      ol = Factory(:order_line,quantity:100)
      sl = Factory(:shipment_line,quantity:95,product:ol.product)
      sl.linked_order_line_id = ol.id
      sl.save!
      expect(described_class.new.close?(ol.order)).to be_truthy
    end
    it "should not close an order < 95% shipped and < 60 days after ship window close" do
      ol = Factory(:order_line,quantity:10000)
      sl = Factory(:shipment_line,quantity:95,product:ol.product)
      sl.linked_order_line_id = ol.id
      sl.save!
      ol.order.update_attributes(ship_window_end:1.day.ago)
      expect(described_class.new.close?(ol.order)).to be_falsey
    end
  end

  describe :process_orders do
    it "should close all that pass close" do
      a = double('a')
      b = double('b')
      c = double('c')
      u = double('user')
      k = described_class.new
      expect(k).to receive(:close?).with(a).and_return true
      expect(k).to receive(:close?).with(b).and_return false
      expect(k).to receive(:close?).with(c).and_return true
      expect(a).to receive(:close!).with(u)
      expect(b).not_to receive(:close!)
      expect(c).to receive(:close!).with(u)
      k.process_orders([a,b,c],u)
    end
  end

end