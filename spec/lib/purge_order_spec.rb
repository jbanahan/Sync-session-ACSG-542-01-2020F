describe OpenChain::PurgeOrder do

  subject { described_class }

  let(:commercial_invoice_line) {Factory(:commercial_invoice_line)}
  let(:some_product) {Factory(:product)}

  describe "run_schedulable" do
    it "executes the purge function" do
      expect(subject).to receive(:purge).once
      subject.run_schedulable
    end
  end

  describe "purge" do
    it "removes orders which are older than 2 years and is not booked or attached to shipment lines" do
      order = Factory(:order, created_at: 2.years.ago)
      order_line = Factory(:order_line, order: order, product: some_product)

      Factory(:piece_set, order_line: order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge
      expect {order.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "removes order of a given age" do
      young_order = Factory(:order, created_at: 1.year.ago)
      young_order_line = Factory(:order_line, order: young_order, product: some_product)

      Factory(:piece_set, order_line: young_order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge 1.year.ago
      expect {young_order.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove if order has connected shipment lines" do
      commercial_invoice_line = Factory(:commercial_invoice_line)
      some_product = Factory(:product)

      order = Factory(:order, created_at: 2.years.ago)
      order_line = Factory(:order_line, order: order, product: some_product)

      shipment_line = Factory(:shipment_line, product: some_product)
      Factory(:piece_set, shipment_line: shipment_line, order_line: order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)
      subject.purge
      expect(Order.where(id: order.id)).to exist
    end

    it "does not remove if booked" do
      booked_order = Factory(:order)
      booked_order_line = Factory(:order_line, order: booked_order, product: some_product)

      Factory(:piece_set, order_line: booked_order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      Factory(:booking_line, order: booked_order)

      subject.purge
      expect(Order.where(id: booked_order.id)).to exist
    end
  end
end
