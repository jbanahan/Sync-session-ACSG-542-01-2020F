describe OpenChain::PurgeShipment do

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
    it "removes shipments which are older than 2 years from the estimated departure date by default" do
      shipment = Factory(:shipment, est_departure_date: 2.years.ago)
      shipment_line = Factory(:shipment_line, shipment: shipment, product: some_product)
      Factory(:piece_set, shipment_line: shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge
      expect {shipment.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "removes shipments of a given age" do
      young_shipment = Factory(:shipment, est_departure_date: 1.year.ago)
      young_shipment_line = Factory(:shipment_line, shipment: young_shipment, product: some_product)
      Factory(:piece_set, shipment_line: young_shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge 1.year.ago
      expect {young_shipment.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "removes based on created_at if estimated departure date is missing" do
      shipment = Factory(:shipment, created_at: 2.years.ago)
      shipment_line = Factory(:shipment_line, shipment: shipment, product: some_product)
      Factory(:piece_set, shipment_line: shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)
      subject.purge
      expect {shipment.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove booked shipments" do
      booked_shipment = Factory(:shipment)
      booked_shipment_line = Factory(:shipment_line, shipment: booked_shipment, product: some_product)
      Factory(:piece_set, shipment_line: booked_shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      Factory(:booking_line, shipment: booked_shipment)

      subject.purge
      expect(Shipment.where(id: booked_shipment.id)).to exist
    end
  end
end
