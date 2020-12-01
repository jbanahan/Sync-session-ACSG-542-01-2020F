describe OpenChain::PurgeShipment do

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
    it "removes shipments which are older than 2 years from the estimated departure date by default" do
      shipment = FactoryBot(:shipment, est_departure_date: 2.years.ago)
      shipment_line = FactoryBot(:shipment_line, shipment: shipment, product: some_product)
      FactoryBot(:piece_set, shipment_line: shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge older_than: 2.years.ago
      expect(shipment).not_to exist_in_db
    end

    it "removes shipments of a given age" do
      young_shipment = FactoryBot(:shipment, est_departure_date: 1.year.ago)
      young_shipment_line = FactoryBot(:shipment_line, shipment: young_shipment, product: some_product)
      FactoryBot(:piece_set, shipment_line: young_shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)

      subject.purge older_than: 1.year.ago
      expect(young_shipment).not_to exist_in_db
    end

    it "removes based on created_at if estimated departure date is missing" do
      shipment = FactoryBot(:shipment, created_at: 2.years.ago)
      shipment_line = FactoryBot(:shipment_line, shipment: shipment, product: some_product)
      FactoryBot(:piece_set, shipment_line: shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)
      subject.purge older_than: 1.year.ago
      expect(shipment).not_to exist_in_db
    end

    it "does not remove newer shipments by created_at date" do
      shipment_line = Factory(:shipment_line, shipment: shipment, product: some_product)
      Factory(:piece_set, shipment_line: shipment_line,
      shipment = Factory(:shipment, created_at: (2.years.ago + 1.minute))
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)
      subject.purge older_than: 2.years.ago
      expect(shipment).to exist_in_db
    end

    it "does not remove newer shipments by est_departure_date date" do
      # Est. Departure Date is an actual date (not datetime)
      shipment = Factory(:shipment, est_departure_date: (2.years.ago + 1.day))
      shipment_line = Factory(:shipment_line, shipment: shipment, product: some_product)
      Factory(:piece_set, shipment_line: shipment_line,
                          commercial_invoice_line: commercial_invoice_line,
                          quantity: 1)
      subject.purge older_than: 2.years.ago
      expect(shipment).to exist_in_db
    end
  end
end
