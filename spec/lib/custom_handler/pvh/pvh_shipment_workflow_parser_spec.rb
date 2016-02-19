require 'spec_helper'

describe OpenChain::CustomHandler::Pvh::PvhShipmentWorkflowParser do
  let (:custom_file) { double "CustomFile" }
  subject { OpenChain::CustomHandler::Pvh::PvhShipmentWorkflowParser.new custom_file }

  let (:workflow_file_line) {
    # This comes directly from an actual pvh file

    ["01/21/16", "2254444", nil, "KAETHE P", "OOLU7360259", "OOLU", "2567813300", "HOT", "JONESVILLE", "CN", "REGINA MIRACLE INTL", "0159419203", "A3", "4W", "315605", "F3646", "       ", "025", "2394", "MODERN T-SHIRT      ", "6212109020", "   ", " ", "5.32", "0.000", "63", "1/29/2016", "1/28/2016", "WOMEN'S BRA", nil, nil, "USSAV", "016", "12/23/2015", "HKHKG", "12/20/15", "                                       ", nil, nil]
  }

  let (:pvh) { Factory(:importer, system_code: "PVH") }
  let (:user) { Factory(:master_user, product_view: true, order_view: true) }
  let (:unlading_port) { Factory(:port, unlocode: "USSAV")}
  let (:lading_port) { Factory(:port, unlocode: "HKHKG")}
  let (:cdefs) {subject.instance_variable_get("@cdefs")}
  let (:existing_product) { Factory(:product, unique_identifier: "#{pvh.system_code}-F3646")}
  let (:existing_order) {
    order = Factory(:order, importer: pvh, order_number: "#{pvh.system_code}-315605")
    order_line = order.order_lines.create! product: existing_product
    order_line.update_custom_value! cdefs[:ord_line_color], "025"
    order
  }
  let (:existing_shipment) {
    shipment = Factory(:shipment, reference: "#{pvh.system_code}-OOLU2567813300", importer: pvh)
    container = shipment.containers.create! container_number: "OOLU7360259"
    sl = shipment.shipment_lines.create! product: existing_product, container: container
    sl.piece_sets.create! order_line: existing_order.order_lines.first, quantity: 10
    shipment
  }

  describe "process_shipment_lines" do
    before :each do
      pvh
      unlading_port
      lading_port
    end
    it "turns file lines into shipment" do
      second_line = workflow_file_line.dup
      # Change JUST the color, the should result in a second distinct order line on the PO 
      second_line[17] = "460"

      third_line = workflow_file_line.dup
      # Change PO and Style and quantity..rest can stay the same.  Need to test that what happens when order and style change
      third_line[14] = "315607"
      third_line[15] = "F3647"
      third_line[18] = "150"
      third_line[25] = "67"

      result = subject.process_shipment_lines user, "OOLU2567813300", [workflow_file_line, second_line, third_line]

      expect(result[:errors]).to eq []
      expect(result[:shipment]).not_to be_blank

      s = result[:shipment]
      expect(s).to be_persisted
      expect(s.reference).to eq "PVH-OOLU2567813300"
      expect(s.importer).to eq pvh
      expect(s.master_bill_of_lading).to eq "OOLU2567813300"
      expect(s.vessel).to eq "KAETHE P"
      expect(s.voyage).to eq "016"
      expect(s.importer_reference).to eq "2254444"
      expect(s.est_arrival_port_date).to eq Date.new(2016, 1, 21)
      expect(s.est_departure_date).to eq Date.new(2015, 12,20)
      expect(s.destination_port).to eq unlading_port
      expect(s.lading_port).to eq lading_port
      expect(s.custom_value(cdefs[:shp_priority])).to eq "HOT"

      expect(s.entity_snapshots.length).to eq 1

      expect(s.containers.length).to eq 1
      cont = s.containers.first

      expect(cont.container_number).to eq "OOLU7360259"

      expect(s.shipment_lines.length).to eq 3
      line = s.shipment_lines.first
      expect(line.quantity).to eq 2394
      expect(line.carton_qty).to eq 63
      expect(line.piece_sets.length).to eq 1
      expect(line.piece_sets.first.quantity).to eq 2394
      expect(line.custom_value(cdefs[:shpln_invoice_number])).to eq "0159419203"

      ol1 = line.piece_sets.first.order_line

      expect(ol1.hts).to eq "6212109020"
      expect(ol1.price_per_unit).to eq 5.32
      expect(ol1.country_of_origin).to eq "CN"
      expect(ol1.custom_value(cdefs[:ord_line_destination_code])).to eq "JONESVILLE"
      expect(ol1.custom_value(cdefs[:ord_line_color])).to eq "025"

      product = ol1.product
      expect(product.unique_identifier).to eq "PVH-F3646"
      expect(product.importer).to eq pvh
      expect(product.custom_value(cdefs[:prod_part_number])).to eq "F3646"
      expect(line.product).to eq product

      oh = ol1.order
      expect(oh.order_number).to eq "PVH-315605"
      expect(oh.customer_order_number).to eq "315605"
      expect(oh.importer).to eq pvh
      expect(oh.custom_value(cdefs[:ord_division])).to eq "A34W"

      line = s.shipment_lines.second
      expect(line.quantity).to eq 2394
      expect(line.carton_qty).to eq 63
      expect(line.piece_sets.length).to eq 1
      expect(line.piece_sets.first.quantity).to eq 2394

      ol2 = line.piece_sets.first.order_line
      expect(ol2).not_to eq ol1
      expect(ol2.hts).to eq "6212109020"
      expect(ol2.price_per_unit).to eq 5.32
      expect(ol2.country_of_origin).to eq "CN"
      expect(ol2.custom_value(cdefs[:ord_line_destination_code])).to eq "JONESVILLE"
      expect(ol2.custom_value(cdefs[:ord_line_color])).to eq "460"

      product2 = ol2.product
      expect(product2).to eq product

      oh2 = ol2.order
      expect(oh2).to eq oh

      line = s.shipment_lines.third
      expect(line.quantity).to eq 150
      expect(line.carton_qty).to eq 67
      expect(line.piece_sets.length).to eq 1
      expect(line.piece_sets.first.quantity).to eq 150

      ol = line.piece_sets.first.order_line

      expect(ol.hts).to eq "6212109020"
      expect(ol.price_per_unit).to eq 5.32
      expect(ol.country_of_origin).to eq "CN"
      expect(ol.custom_value(cdefs[:ord_line_destination_code])).to eq "JONESVILLE"
      expect(ol.custom_value(cdefs[:ord_line_color])).to eq "025"

      product = ol.product
      expect(product.unique_identifier).to eq "PVH-F3647"
      expect(product.importer).to eq pvh
      expect(product.custom_value(cdefs[:prod_part_number])).to eq "F3647"
      expect(line.product).to eq product

      oh = ol.order
      expect(oh.order_number).to eq "PVH-315607"
      expect(oh.customer_order_number).to eq "315607"
      expect(oh.importer).to eq pvh
      expect(oh.custom_value(cdefs[:ord_division])).to eq "A34W"
    end

    it "updates an existing shipment, order and product" do
      existing_shipment

      result = subject.process_shipment_lines user, "OOLU2567813300", [workflow_file_line]

      expect(result[:errors]).to eq []
      expect(result[:shipment]).not_to be_blank
      shipment = result[:shipment]

      # Just make sure the shipment, order and product used were the expecting existing ones.
      expect(shipment).to eq existing_shipment
      expect(shipment.containers.length).to eq 1
      expect(shipment.shipment_lines.length).to eq 1
      expect(shipment.shipment_lines.first).to eq existing_shipment.shipment_lines.first
      expect(shipment.shipment_lines.first.product).to eq existing_shipment.shipment_lines.first.product
      expect(shipment.shipment_lines.first.piece_sets.first.order_line).to eq existing_order.order_lines.first
      expect(shipment.shipment_lines.first.piece_sets.first.order_line.order).to eq existing_order
    end

    it "does not create new snapshots when no updates have been done to modules" do
      # The easiest way to do a check that smart snapshotting is being done is to 
      # just run the same lines through twice (which is really what's going to happen in the system anyway).
      result = subject.process_shipment_lines user, "OOLU2567813300", [workflow_file_line]

      result = subject.process_shipment_lines user, "OOLU2567813300", [workflow_file_line]

      expect(result[:errors]).to eq []
      expect(result[:shipment]).not_to be_blank
      shipment = result[:shipment]

      shipment.reload

      expect(shipment.entity_snapshots.length).to eq 1
      expect(shipment.shipment_lines.first.product.entity_snapshots.length).to eq 1
      expect(shipment.shipment_lines.first.piece_sets.first.order_line.order.entity_snapshots.size).to eq 1
    end

    it "handles updating shipments with new lines" do
      existing_shipment.shipment_lines.first.destroy

      result = subject.process_shipment_lines user, "OOLU2567813300", [workflow_file_line]

      expect(result[:errors]).to eq []
      expect(result[:shipment]).not_to be_blank
      shipment = result[:shipment]

      # Just make sure the shipment line is created and it's not equal to the one we destroyed
      expect(shipment).to eq existing_shipment
      expect(shipment.shipment_lines.length).to eq 1
      expect(shipment.shipment_lines.first).not_to eq existing_shipment.shipment_lines.first
      expect(shipment.shipment_lines.first.product).to eq existing_product
    end
  end

  describe "can_view?" do
    let (:can_view_user) { Factory(:master_user)}
    let (:www_setup) { 
      setup = MasterSetup.new system_code: "www-vfitrack-net"
      MasterSetup.stub(:get).and_return setup
    }

    it "allows www-vfitrack-net users" do
      www_setup
      expect(described_class.can_view? can_view_user).to be_true
    end

    it "disallows non-master users" do
      www_setup
      expect(described_class.can_view? Factory(:user)).to be_false
    end

    it "disallows non-www systems" do
      expect(described_class.can_view? can_view_user).to be_false
    end
  end

  describe "parse" do
    let (:file_data) {
      secondary_line = workflow_file_line.dup
      # change the master bill, so it should pick up as another distinct shipment
      secondary_line[6] = "1234567890"
      [
        [""],
        ["Eta", "Reference #", "Worksheet", "Vessel", "shipment"],
        workflow_file_line,
        [""],
        workflow_file_line,
        [""],
        secondary_line
      ]
    }



    it "parses file xl file data into distinct shipments" do
      OpenChain::XLClient.any_instance.should_receive(:all_row_values).and_yield(file_data[0]).and_yield(file_data[1]).and_yield(file_data[2]).and_yield(file_data[3]).and_yield(file_data[4]).and_yield(file_data[5]).and_yield(file_data[6])
      subject.should_receive(:process_shipment_lines).with User.integration, "OOLU2567813300", [file_data[2], file_data[4]]
      subject.should_receive(:process_shipment_lines).with User.integration, "OOLU1234567890", [file_data[6]]

      subject.parse CustomFile.new
    end
  end

  describe "process" do
    it "parses file and sends message to user" do
      custom_file.stub(:attached_file_name).and_return "file.xlsx"
      subject.should_receive(:parse).with(custom_file).and_return [{shipment: Shipment.new, errors: nil}, {shipment: Shipment.new, errors: nil}]
      subject.process user

      expect(user.messages.length).to eq 1
      m = user.messages.first
      expect(m.subject).to eq "PVH Workflow Processing Complete"
      expect(m.body).to eq "PVH Workflow File 'file.xlsx' has finished processing 2 shipments. 2 shipments were successfully processed."
    end

    it "reports errors with parsing" do
       custom_file.stub(:attached_file_name).and_return "file.xlsx"
      subject.should_receive(:parse).with(custom_file).and_return [{shipment: Shipment.new, errors: nil}, {shipment: nil, errors: ["Error", "Error2"]}]
      subject.process user

      expect(user.messages.length).to eq 1
      m = user.messages.first
      expect(m.subject).to eq "PVH Workflow Processing Complete With Errors"
      expect(m.body).to eq "PVH Workflow File 'file.xlsx' has finished processing 2 shipments. 1 shipments was successfully processed.<br>The following 2 errors were received:<br>Error<br>Error2"
    end
  end

end