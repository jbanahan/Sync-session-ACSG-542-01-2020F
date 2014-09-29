require 'spec_helper'

describe OpenChain::CustomHandler::JJill::JJillOrderCloser do
  describe :close? do
    it "should close an order > 60 days after ship_window_end" do
      o = Order.new(ship_window_end:61.days.ago)
      expect(described_class.new.close?(o)).to be_true
    end
    it "should close an order 95%+ shipped" do
      ol = Factory(:order_line,quantity:100)
      sl = Factory(:shipment_line,quantity:95,product:ol.product)
      sl.linked_order_line_id = ol.id
      sl.save!
      expect(described_class.new.close?(ol.order)).to be_true
    end
    it "should not close an order < 95% shipped and < 60 days after ship window close" do
      ol = Factory(:order_line,quantity:10000)
      sl = Factory(:shipment_line,quantity:95,product:ol.product)
      sl.linked_order_line_id = ol.id
      sl.save!
      ol.order.update_attributes(ship_window_end:1.day.ago)
      expect(described_class.new.close?(ol.order)).to be_false
    end
  end

  describe :process_orders do
    it "should close all that pass close" do
      a = double('a')
      b = double('b')
      c = double('c')
      u = double('user')
      k = described_class.new
      k.should_receive(:close?).with(a).and_return true
      k.should_receive(:close?).with(b).and_return false
      k.should_receive(:close?).with(c).and_return true
      a.should_receive(:close!).with(u)
      b.should_not_receive(:close!)
      c.should_receive(:close!).with(u)
      k.process_orders([a,b,c],u)
    end
  end

end