require 'spec_helper'

describe BookingLine do
  describe 'when validating' do
    describe 'when order line id is present' do
      it 'sets the order id and product id' do
        p = Factory(:product)
        ol = Factory(:order_line,product:p)
        s = Factory(:shipment)
        bl = s.booking_lines.create!(order_line:ol)
        expect(bl.product_id).to eq p.id
        expect(bl.order_id).to eq ol.order_id
      end
    end
  end

  describe "customer_order_number" do
    let (:line) {BookingLine.new order: Order.new(order_number: "ORD#", customer_order_number: "CUST ORD #")}

    it "uses linked order" do
      expect(line.customer_order_number).to eq "CUST ORD #"
    end

    it "uses order line's order" do
      line.order_line = OrderLine.new(order: line.order)
      line.order = nil
      expect(line.customer_order_number).to eq "CUST ORD #"
    end

    it "uses order's order number if customer order number is blank" do
      line.order.customer_order_number = ""
      expect(line.customer_order_number).to eq "ORD#"
    end
  end
end
