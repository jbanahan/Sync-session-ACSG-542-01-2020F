describe BookingLine do
  describe 'when validating' do
    describe 'when order line id is present' do
      it 'sets the order id and product id' do
        p = create(:product)
        ol = create(:order_line, product:p)
        s = create(:shipment)
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

  describe "product_summed_order_quantity" do
    it "returns the total order quantity for associated product" do
      o = create(:order)
      p = create(:product)
      s1 = create(:shipment)
      s2 = create(:shipment)

      ol1 = create(:order_line, order: o, quantity: 2, product: p)
      ol2 = create(:order_line, order: o, quantity: 3, product: p)
      ol4 = create(:order_line, order: o, quantity: 6, product: p) # different shipment
      ol3 = create(:order_line, order: o, quantity: 4, product: create(:product)) # different product

      bl = create(:booking_line, order: o, order_line: ol1, product: p, shipment: s1)
      create(:booking_line, order: o, order_line: ol2, product: p, shipment: s1)
      create(:booking_line, order: o, order_line: ol3, product: p, shipment: s1)
      create(:booking_line, order: o, order_line: ol4, product: p, shipment: s2)

      expect(bl.product_summed_order_quantity).to eq 11
    end
  end
end
