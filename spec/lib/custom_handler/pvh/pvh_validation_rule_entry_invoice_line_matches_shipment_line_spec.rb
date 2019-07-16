describe OpenChain::CustomHandler::Pvh::PvhValidationRuleEntryInvoiceLineMatchesShipmentLine do

  let! (:pvh) {
    Factory(:importer, system_code: "PVH")
  }

  let (:product) {
    Factory(:product, importer: pvh, unique_identifier: "PVH-PART")
  }

  let (:order) {
    order = Factory(:order, order_number: "ORDER", customer_order_number: "ORDER", importer_id: pvh.id)
    order_line = order.order_lines.create! product_id: product.id, quantity: 10, line_number: 1, price_per_unit: 10
    order_line = order.order_lines.create! product_id: product.id, quantity: 20, line_number: 8, price_per_unit: 5
    order
  }

  let! (:shipment) {
    s = Factory(:shipment, master_bill_of_lading: "MBOL1234567890", house_bill_of_lading: "HBOL987654321", mode: "OCEAN", importer: pvh)
    c = s.containers.create! container_number: "ABCD1234567890", fcl_lcl: "FCL"

    l = Factory(:shipment_line, shipment: s, container: c, quantity: 10, product: product, linked_order_line_id: order.order_lines.first.id, gross_kgs: 200)
    l2 = Factory(:shipment_line, shipment: s, container: c, quantity: 20, product: product, linked_order_line_id: order.order_lines.second.id, gross_kgs: 100)

    l.shipment.reload
  }

  let (:entry) {
    e = Factory(:entry, broker_reference: "12345", importer_id: pvh.id, customer_number: "PVH", container_numbers: "ABCD1234567890", master_bills_of_lading: "MBOL9999\n MBOL1234567890", transport_mode_code: "10")
    container = e.containers.create! container_number: "ABCD1234567890"
    invoice = e.commercial_invoices.create! invoice_number: "1"
    line = invoice.commercial_invoice_lines.create! po_number: "ORDER", part_number: "PART", quantity: 20, unit_price: 5, container_id: container.id
    e.reload
  }

  describe "run_validation" do
    context "with ocean shipment" do
      it "finds valid match" do
        expect(subject.run_validation entry).to be_blank
      end

      it "finds valid match without container number on invoice line" do
        entry.commercial_invoices.first.commercial_invoice_lines.first.container.destroy
        entry.reload
        expect(subject.run_validation entry).to be_blank
      end

      it "errors if part numbers don't match" do
        product.update_attributes! unique_identifier: "PVH-PART2"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if order numbers don't match" do
        order.update_attributes! customer_order_number: "ORDER2"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if container numbers don't match" do
        shipment.containers.first.update_attributes! container_number: "CONT"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if no shipment found by master bill" do
        shipment.update_attributes! master_bill_of_lading: "MBOL"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      context "with Ocean LCL shipment" do
        before :each do 
          entry.update! fcl_lcl: "LCL"
          shipment.shipment_lines.last.update! invoice_number: "1"
        end

        it "uses invoice number as an extra match point" do
          expect(subject.run_validation entry).to be_blank
        end

        it "errors if invoice does not match" do
          shipment.shipment_lines.last.update! invoice_number: "NOTAMATCH"
          expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
        end
      end
    end

    context "with air shipment" do
      before :each do 
        entry.update_attributes! transport_mode_code: "40", house_bills_of_lading: "HBOL987654321"
        shipment.update_attributes! mode: "AIR"
        shipment.containers.first.update_attributes! container_number: "HBOL987654321"
        entry.containers.first.update_attributes! container_number: "HBOL987654321"
        entry.reload
      end

      it "finds valid match" do
        expect(subject.run_validation entry).to be_blank
      end

      it "finds valid match without container number on invoice line" do
        entry.commercial_invoices.first.commercial_invoice_lines.first.container.destroy
        entry.reload
        expect(subject.run_validation entry).to be_blank
      end

      it "errors if part numbers don't match" do
        product.update_attributes! unique_identifier: "PVH-PART2"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if order numbers don't match" do
        order.update_attributes! customer_order_number: "ORDER2"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if no shipment found by house bill" do
        shipment.update_attributes! house_bill_of_lading: "HBOL", master_bill_of_lading: nil
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end
    end

    context "with truck shipment" do
      before :each do 
        entry.update_attributes! transport_mode_code: "30"
        shipment.update_attributes! mode: "TRUCK"
        shipment.containers.first.update_attributes! container_number: "MBOL1234567890"
        entry.containers.destroy_all
        entry.reload
      end

      it "finds valid match" do
        expect(subject.run_validation entry).to be_blank
      end

      it "errors if part numbers don't match" do
        product.update_attributes! unique_identifier: "PVH-PART2"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if order numbers don't match" do
        order.update_attributes! customer_order_number: "ORDER2"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end

      it "errors if no shipment found by master bill" do
        shipment.update_attributes! master_bill_of_lading: "MBOL"
        expect(subject.run_validation entry).to include "PO # ORDER / Part # PART - Failed to find matching PVH Shipment Line."
      end
    end
  end
end