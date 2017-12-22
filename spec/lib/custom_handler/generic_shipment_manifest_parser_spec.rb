require 'spec_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

describe OpenChain::CustomHandler::GenericShipmentManifestParser do
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def add_row_data rows, row, col, data
    rows[row] = [] if rows[row].nil?
    rows[row][col] = data
  end

  def add_details_row rows, row, starting_column, data
    counter = -1
    (starting_column .. (starting_column + data.length)).each do |i|
      add_row_data rows, row, i, data[counter+=1]
    end
  end

  describe "process_rows" do
    let (:importer) { Factory(:importer) }
    let (:user) { Factory(:user, company: importer) }
    let (:shipment) { Shipment.new reference: "Reference", importer: importer}
    let (:rows) {
      rows = []
      add_row_data rows, 28, 5, "Receipt"
      add_row_data rows, 28, 11, "2016-06-01"
      add_row_data rows, 30, 8, "TERMS"
      add_row_data rows, 30, 11, "Type"
      add_row_data rows, 28, 8, "Mode"
      add_row_data rows, 35, 0, "Marks And Numbers"

      add_details_row rows, 35, 2, ["CustOrdNum", "Style", "Sku", "1234.56.7890", 10, 100, "", 2, 200, "", "Container#", "Seal#"]
      rows
    }
    let(:cdefs) { self.class.prep_custom_definitions([:prod_part_number]) }

    let (:product) {
      p = Factory(:product, importer: importer)
      p.update_custom_value! cdefs[:prod_part_number], "Style"
      p
    }

    let! (:order) {
      o = Factory(:order, importer: importer, order_number: "OrdNum", customer_order_number: "CustOrdNum")
      o.order_lines.create! product_id: product.id, sku: "Sku"

      o
    }

    before :each do 
      allow(shipment).to receive(:can_edit?).with(user).and_return true
      allow(shipment).to receive(:create_async_snapshot)
    end

    it "throws exception if data contains unmatched order" do
      order.update_attributes! customer_order_number: "foo"
      expect{subject.process_rows shipment, rows, user}.to raise_error "Order Number CustOrdNum not found."
      expect(shipment.shipment_lines.length).to eq 0
    end

    it "parses shipment data, linking to order lines by sku" do
      order
      add_details_row rows, 35, 2, ["CustOrdNum", "", "Sku", "1234.56.7890", 10, 100, "", 2, 200, "", "Container#", "Seal#"]

      subject.process_rows shipment, rows, user
      expect(shipment).to be_persisted

      expect(shipment.shipment_lines.length).to eq 1
      l = shipment.shipment_lines.first
      expect(l.line_number).to eq 1
      expect(l.quantity).to eq 100
      expect(l.container).to eq shipment.containers.first
      expect(l.cbms).to eq 2
      expect(l.gross_kgs).to eq 200
      expect(l.carton_qty).to eq 10
    end

    it "parses shipment data, linking to order lines by product part number" do
      order
      add_details_row rows, 35, 2, ["CustOrdNum", "Style", "", "1234.56.7890", 10, 100, "", 2, 200, "", "Container#", "Seal#"]
      subject.process_rows shipment, rows, user
      expect(shipment).to be_persisted

      # There's no change in the data that's parsed based on the order line matching algorithm, so just
      # make sure a shipment line was created.
      expect(shipment.shipment_lines.length).to eq 1
    end

    it "appends marks and numbers to existing marks and numbers" do
      shipment.marks_and_numbers = "Existing"
      subject.process_rows shipment, rows, user
      expect(shipment.marks_and_numbers).to eq "Existing Marks And Numbers"
    end

    it "uses correct shipment mode for ocean CY/CY" do
      add_row_data rows, 28, 8, "Ocean"
      add_row_data rows, 30, 11, "CY/CY"

      subject.process_rows shipment, rows, user

      expect(shipment.mode).to eq "Ocean - FCL"
    end

    it "uses correct shipment mode for ocean CY/CFS" do
      add_row_data rows, 28, 8, "Ocean"
      add_row_data rows, 30, 11, "CY/CFS"

      subject.process_rows shipment, rows, user

      expect(shipment.mode).to eq "Ocean - FCL"
    end

    it "uses correct shipment mode for ocean CFS/CY" do
      add_row_data rows, 28, 8, "Ocean"
      add_row_data rows, 30, 11, "CFS/CY"

      subject.process_rows shipment, rows, user

      expect(shipment.mode).to eq "Ocean - LCL"
    end

    it "uses correct shipment mode for ocean CFS/CFS" do
      add_row_data rows, 28, 8, "Ocean"
      add_row_data rows, 30, 11, "CFS/CFS"

      subject.process_rows shipment, rows, user

      expect(shipment.mode).to eq "Ocean - LCL"
      expect(shipment.lcl).to be_truthy
    end

    it "handles manufacturer_address_id if provided in constructor options" do
      order
      add_details_row rows, 35, 2, ["CustOrdNum", "", "Sku", "1234.56.7890", 10, 100, "", 2, 200, "", "Container#", "Seal#"]

      address = Factory(:full_address)
      described_class.new(manufacturer_address_id: address.id).process_rows shipment, rows, user
      expect(shipment).to be_persisted

      expect(shipment.shipment_lines.map {|l| l.manufacturer_address_id }.uniq.first).to eq address.id
    end

    it "fails when order belongs to another shipment if check_orders provided in constructor options" do
      ol = order.order_lines.first
      sl = Factory(:shipment_line, shipment: Factory(:shipment, reference: "REF2"), product: product)
      PieceSet.create! order_line: ol, shipment_line: sl, quantity: 1

      expect{described_class.new(check_orders: true).process_rows shipment, rows, user}.to raise_error 'ORDERS FOUND ON MULTIPLE SHIPMENTS: ~{"CustOrdNum":["REF2"]}'
      expect(shipment).to_not be_persisted
    end
  end
end
