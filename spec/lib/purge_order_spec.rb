describe OpenChain::PurgeOrder do

  subject { described_class }

  let(:commercial_invoice_line) {FactoryBot(:commercial_invoice_line)}
  let(:some_product) {FactoryBot(:product)}

  describe "run_schedulable" do

    let (:now) { Time.zone.now }

    it "executes the purge function" do
      start_date = now.in_time_zone("America/New_York").beginning_of_day - 3.years
      expect(subject).to receive(:purge).with(older_than: start_date)

      Timecop.freeze(now) do
        subject.run_schedulable({})
      end
    end

    it "uses alternate years_old value" do
      start_date = now.in_time_zone("America/New_York").beginning_of_day - 10.years
      expect(subject).to receive(:purge).with(older_than: start_date)

      Timecop.freeze(now) do
        subject.run_schedulable({"years_old" => 10})
      end
    end
  end

  describe "purge" do
    it "removes orders which are older than given date and is not booked or attached to shipment lines" do
      order = FactoryBot(:order, created_at: 2.years.ago)
      order_line = FactoryBot(:order_line, order: order, product: some_product)

      FactoryBot(:piece_set, order_line: order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge older_than: date
      expect { order.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "removes order of a given age" do
      young_order = FactoryBot(:order, created_at: 1.year.ago)
      young_order_line = FactoryBot(:order_line, order: young_order, product: some_product)

      FactoryBot(:piece_set, order_line: young_order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge older_than: 1.year.ago
      expect { young_order.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove if order has connected shipment lines" do
      commercial_invoice_line = FactoryBot(:commercial_invoice_line)
      some_product = FactoryBot(:product)

      order = FactoryBot(:order, created_at: 2.years.ago)
      order_line = FactoryBot(:order_line, order: order, product: some_product)

      shipment_line = FactoryBot(:shipment_line, product: some_product)
      FactoryBot(:piece_set, shipment_line: shipment_line, order_line: order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge older_than: 2.years.ago
      expect(Order.where(id: order.id)).to exist
    end

    it "does not remove if booked" do
      booked_order = FactoryBot(:order)
      booked_order_line = FactoryBot(:order_line, order: booked_order, product: some_product)

      FactoryBot(:piece_set, order_line: booked_order_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      FactoryBot(:booking_line, order: booked_order)

      subject.purge older_than: 2.years.ago
      expect(Order.where(id: booked_order.id)).to exist
    end
  end
end
