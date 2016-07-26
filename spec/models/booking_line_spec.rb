require 'spec_helper'

describe BookingLine do
  describe 'when validating' do
    describe 'when order line id is present' do
      it 'the line is invalid if product id is present' do
        line = BookingLine.new product_id:1, order_line_id:1
        expect(line).to be_invalid
      end

      it 'the line is invalid if order id is present' do
        line = BookingLine.new order_id:1, order_line_id:1
        expect(line).to be_invalid
      end

      it 'the line is valid if order and product are not present' do
        line = BookingLine.new order_line_id:1
        expect(line).to be_valid
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
