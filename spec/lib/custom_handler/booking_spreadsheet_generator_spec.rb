describe OpenChain::CustomHandler::BookingSpreadsheetGenerator do

  describe "shipment_vendor_info" do
    subject { described_class }
    let (:order_line) {
      order_line = Factory(:order_line)
      o = order_line.order
      o.order_from_address = Factory(:address, company: o.vendor)
      o.save!

      order_line
    }

    let (:shipment_line) {
      shipment_line = Factory(:shipment_line, product: order_line.product)
      shipment_line.linked_order_line_id = order_line.id
      shipment_line.save!

      shipment_line
    }

    let (:booking_line) {
      Factory(:booking_line, order: order_line.order)
    }

    it "extracts vendor info from shipment lines" do
      info = subject.shipment_vendor_info([shipment_line])
      expect(info[:vendor]).to eq order_line.order.vendor
      expect(info[:vendor_address]).to eq order_line.order.order_from_address
    end

    it "extracts vendor info from booking lines" do
      info = subject.shipment_vendor_info([booking_line])
      expect(info[:vendor]).to eq order_line.order.vendor
      expect(info[:vendor_address]).to eq order_line.order.order_from_address
    end
  end

  describe "generate_file" do

    let (:xl_client) {
      xl = instance_double(OpenChain::XLClient)
    }

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:uuid).and_return "uuid"
      ms
    }

    let (:shipment) {
      s = Factory(:shipment, reference: "reference", forwarder: Factory(:company, name: "Forwarder"), requested_equipment: "Equipment", cargo_ready_date: Date.new(2016, 10, 5), mode: "Mode", shipment_type: "Type",
                  number_of_packages: 20, number_of_packages_uom: "CTNS", gross_weight: BigDecimal(10), volume: BigDecimal(20), lacey_act: true, hazmat: false, marks_and_numbers: "Marks\n And\nNumbers",
                  first_port_receipt: Factory(:port, name: "Port Name", unlocode: "AAAAA"), importer: Factory(:importer, name: "Importer"))
    }

    let (:order_line) {
      order = Factory(:order, customer_order_number: "Order", vendor: Factory(:vendor, name: "Vendor Name"))
      product = Factory(:product, unique_identifier: "Product")
      order_line = Factory(:order_line, order: order, product: product, line_number: 2, unit_of_measure: "FT")

      order.order_from_address = Factory(:address, company: order.vendor, line_1: "Address 1", line_2: "Address 2", city: "City", state: "State", postal_code: "12345", country: Factory(:country, iso_code: "US", name: "USA"))
      order.save!

      order_line
    }

    def setup_xl_header_expectations xl
      expect(xl).to receive(:set_cell).with(0, 2, "A", "Vendor Name")
      expect(xl).to receive(:set_cell).with(0, 3, "A", "Address 1")
      expect(xl).to receive(:set_cell).with(0, 4, "A", "Address 2")
      expect(xl).to receive(:set_cell).with(0, 5, "A", "City, State 12345 US")
      expect(xl).to receive(:set_cell).with(0, 2, "G", "Importer")
      expect(xl).to receive(:set_cell).with(0, 8, "A", "Forwarder")
      expect(xl).to receive(:set_cell).with(0, 8, "G", "Equipment")
      expect(xl).to receive(:set_cell).with(0, 10, "A", "2016-10-05")
      expect(xl).to receive(:set_cell).with(0, 10, "C", "Mode")
      expect(xl).to receive(:set_cell).with(0, 10, "E", "Type")
      expect(xl).to receive(:set_cell).with(0, 10, "G", "Port Name - AAAAA")
      expect(xl).to receive(:set_cell).with(0, 12, "A", "20 CTNS")
      expect(xl).to receive(:set_cell).with(0, 12, "C", BigDecimal(10))
      expect(xl).to receive(:set_cell).with(0, 12, "E", BigDecimal(20))
      expect(xl).to receive(:set_cell).with(0, 12, "G", "Y") # Lacey
      expect(xl).to receive(:set_cell).with(0, 12, "H", "N") # Hazmat
      expect(xl).to receive(:set_cell).with(0, 12, "I", "N") # Export License?
      expect(xl).to receive(:set_cell).with(0, 12, "K", "N") # SWPM
      expect(xl).to receive(:set_cell).with(0, 14, "A", "Marks")
      expect(xl).to receive(:set_cell).with(0, 15, "A", " And")
      expect(xl).to receive(:set_cell).with(0, 16, "A", "Numbers")
    end

    def setup_other_expectations xl
      allow(subject).to receive(:xl).and_return xl
      expect(xl).to receive(:save).with("uuid/shipment/reference.xlsx", bucket: "chainio-temp")
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("chainio-temp", "uuid/shipment/reference.xlsx", original_filename: "reference.xlsx").and_yield "file"
    end

    context "with shipment line" do
      let (:shipment_line) {
        line = Factory(:shipment_line, shipment: shipment, line_number: 1, quantity: BigDecimal(30), variant: Factory(:variant, variant_identifier: "Variant", product: order_line.product), product: order_line.product)
        line.linked_order_line_id = order_line.id
        line.save!

        line
      }

      def setup_line_expectations xl
        expect(xl).to receive(:set_cell).with(0, 20, "A", 1)
        expect(xl).to receive(:set_cell).with(0, 20, "B", "Order")
        expect(xl).to receive(:set_cell).with(0, 20, "D", 2)
        expect(xl).to receive(:set_cell).with(0, 20, "E", "Product")
        expect(xl).to receive(:set_cell).with(0, 20, "G", BigDecimal(30))
        expect(xl).to receive(:set_cell).with(0, 20, "H", "FT")
        expect(xl).to receive(:set_cell).with(0, 20, "I", "Variant")
      end

      it "generates data to spreadsheet with xl_client" do
        setup_xl_header_expectations(xl_client)
        setup_line_expectations(xl_client)
        setup_other_expectations(xl_client)

        subject.generate_file(User.integration, shipment, [shipment_line]) do |file|
          # We're mocking out the creation of the file, so just make sure the mocked file download is what's yielded
          expect(file).to eq "file"
        end
      end
    end

    context "with booking line" do
      let (:booking_line) {
        Factory(:booking_line, shipment: shipment, line_number: 1, quantity: BigDecimal(30), variant: Factory(:variant, variant_identifier: "Variant", product: order_line.product), product: order_line.product, order_line: order_line, order: order_line.order)
      }

      def setup_line_expectations xl
        expect(xl).to receive(:set_cell).with(0, 20, "A", 1)
        expect(xl).to receive(:set_cell).with(0, 20, "B", "Order")
        expect(xl).to receive(:set_cell).with(0, 20, "D", 2)
        expect(xl).to receive(:set_cell).with(0, 20, "E", "Product")
        expect(xl).to receive(:set_cell).with(0, 20, "G", BigDecimal(30))
        expect(xl).to receive(:set_cell).with(0, 20, "H", "FT")
        expect(xl).to receive(:set_cell).with(0, 20, "I", "Variant")
      end

      it "generates data to spreadsheet with xl_client" do
        setup_xl_header_expectations(xl_client)
        setup_line_expectations(xl_client)
        setup_other_expectations(xl_client)

        subject.generate_file(User.integration, shipment, [booking_line]) do |file|
          # We're mocking out the creation of the file, so just make sure the mocked file download is what's yielded
          expect(file).to eq "file"
        end
      end
    end
  end


  describe "generate" do
    subject { described_class }

    it "calls instance method and yields the yielded result from that method" do
      user = instance_double(User)
      shipment = instance_double(Shipment)
      shipment_line = instance_double(ShipmentLine)

      expect_any_instance_of(described_class).to receive(:generate_file).with(user, shipment, [shipment_line]).and_yield "file"

      subject.generate(user, shipment, [shipment_line]) do |file|
        expect(file).to eq "file"
      end
    end
  end
end