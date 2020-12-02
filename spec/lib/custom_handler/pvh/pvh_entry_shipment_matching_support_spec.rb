describe OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport do

  subject {
    Class.new do
      include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport
    end.new
  }

  let (:importer) { create(:importer, system_code: "PVH")}
  let! (:ocean_shipment) { create(:shipment, mode: "Ocean", master_bill_of_lading: "MBOL", house_bill_of_lading: "SEAHBOL", importer: importer)}
  let! (:air_shipment) { create(:shipment, mode: "Air", master_bill_of_lading: "AIRMBOL", house_bill_of_lading: "HBOL", importer: importer)}

  describe "find_shipments" do

    it "finds US ocean shipments by master bill" do
      expect(subject.find_shipments "10", "MBOL", "HBOL").to eq [ocean_shipment]
      expect(subject.found_shipments).to eq [ocean_shipment]
      # Look-up is not repeated.  We should return the originally found shipment.
      expect(subject.find_shipments "101", "MIBOL", "HIBOL").to eq [ocean_shipment]
      # Nothing should be found when a second actual look-up is forced.
      expect(subject.find_shipments "101", "MIBOL", "HIBOL", force_lookup:true).to eq []
    end

    it "finds CA ocean shipments by master bill" do
      expect(subject.find_shipments "9", "MBOL", "HBOL").to eq [ocean_shipment]
      expect(subject.found_shipments).to eq [ocean_shipment]
    end

    it "finds US air shipments by house bill" do
      expect(subject.find_shipments "40", "MBOL", "HBOL").to eq [air_shipment]
      expect(subject.found_shipments).to eq [air_shipment]
    end

    it "finds CA air shipments by house bill" do
      expect(subject.find_shipments "1", "MBOL", "HBOL").to eq [air_shipment]
      expect(subject.found_shipments).to eq [air_shipment]
    end

    it "returns blank array if nothing found" do
      expect(subject.find_shipments "1", "BOL", "BOL").to eq []
      expect(subject.found_shipments).to eq []
    end

    it "does not find shipments if modes don't match" do
      ocean_shipment.update_attributes! mode: "SomeOtherMode"
      expect(subject.find_shipments "10", "MBOL", "HBOL").to eq []
    end

    it "does not find non-PVH shipments" do
      ocean_shipment.update_attributes! importer_id: create(:importer).id
      expect(subject.find_shipments "10", "MBOL", "HBOL").to eq []
    end
  end

  describe "find_shipment_container" do
    let! (:ocean_container) {
      ocean_shipment.containers.create! container_number: "CONTAINER"
    }

    it "finds matching container" do
      expect(subject.find_shipment_container [air_shipment, ocean_shipment], "CONTAINER").to eq ocean_container
    end

    it "returns nil if nothing found" do
      expect(subject.find_shipment_container [air_shipment, ocean_shipment], "Another Container").to be_nil
    end
  end


  describe "find_shipment_line" do
    let! (:ocean_container) {
      ocean_shipment.containers.create! container_number: "CONTAINER"
    }

    let! (:product) { create(:product, unique_identifier: "PVH-12345", importer: importer) }

    let! (:order) {
      o = create(:order, order_number: "PVH-ORDER_1", customer_order_number: "ORDER_1")
      o.order_lines.create! line_number: 1, product_id: product.id, quantity: 100
      o.order_lines.create! line_number: 2, product_id: product.id, quantity: 200
      o
    }

    let! (:ocean_shipment_lines) {
      l = create(:shipment_line, shipment: ocean_shipment, container: ocean_container, quantity: 100, product: product, linked_order_line_id: order.order_lines.first.id)
      l2 = create(:shipment_line, shipment: ocean_shipment, container: ocean_container, quantity: 200, product: product, linked_order_line_id: order.order_lines.second.id)
      ocean_shipment.reload
      [l, l2]
    }

    it "finds shipment line with exact data matches" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.first
      expect(subject.found_shipment_lines.to_a).to eq [ocean_shipment_lines.first]

      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 200)).to eq ocean_shipment_lines.second
      expect(subject.found_shipment_lines.to_a).to eq ocean_shipment_lines
    end

    it "finds shipment line with quantity that doesn't match exactly" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 75)).to eq ocean_shipment_lines.first
    end

    it "does not return the same line more than once" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.first
      # Even though the params are the same, the second call here should return the second line
      # since the first line was already returned.
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.second
    end

    it "does not search by container if container number is blank" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.first
    end

    it "returns nil if no match found by part number" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "NOTAPART", 100)).to be_nil
    end

    it "returns nil if no match found by order number" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "NOT_ORDER_1", "12345", 100)).to be_nil
    end

    it "returns nil when all lines have already been returned and nothing is left to match" do
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.first
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 200)).to eq ocean_shipment_lines.second
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 200)).to be_nil
    end

    it "allows matching a PO line multiple times if the tariff number on the line is 9999999999" do
      order.order_lines.first.update_attributes! hts: "9999999999"
      ocean_shipment.shipment_lines.second.destroy
      ocean_shipment.reload

      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.first
      expect(subject.find_shipment_line([air_shipment, ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100)).to eq ocean_shipment_lines.first
    end

    it "allows matching based on invoice number" do
      ocean_shipment.shipment_lines.first.update! invoice_number: "INVOICE 1"
      ocean_shipment.shipment_lines.second.update! invoice_number: "INVOICE 2"
      ocean_shipment.reload

      # Normally, since the quantity given in 100, without the invoice number given, you'd get the first shipment line back (since it has a quantity of 100)
      # but since we're giving another invoice, we shoudl get the second line.
      expect(subject.find_shipment_line([ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100, invoice_number: "INVOICE 2")).to eq ocean_shipment_lines.second

      # We should get the first shipment line back now because of the fall back to not using the invoice matching if there are no matches based on it
      expect(subject.find_shipment_line([ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100, invoice_number: "INVOICE 2")).to eq ocean_shipment_lines.first

      # Since there's no more lines to match, then we should get nil
      expect(subject.find_shipment_line([ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100, invoice_number: "INVOICE 2")).to be_nil
    end

    it "clean up invoice number before doing matching" do
      ocean_shipment.shipment_lines.first.update! invoice_number: "INVOICE 1"
      ocean_shipment.shipment_lines.second.update! invoice_number: "...---- INVOICE      2////"
      ocean_shipment.reload

      # The matching should only be being done based on alphanumeric characters..not punctuation.
      expect(subject.find_shipment_line([ocean_shipment], "CONTAINER", "ORDER_1", "12345", 100, invoice_number: "////****INVOICE----2")).to eq ocean_shipment_lines.second
    end
  end
end