describe OpenChain::CustomHandler::Pvh::PvhDeliveryOrderSpreadsheetGenerator do

  let(:product) { FactoryBot(:product, importer: importer) }

  let(:custom_defintions) {
    # Need this to force creation of the custom definitions
    inst = described_class.new
    inst.instance_variable_get("@cdefs")
  }

  let(:order1) {
    dest_cd = custom_defintions[:ord_line_destination_code]
    div_cd = custom_defintions[:ord_line_division]

    o = FactoryBot(:order, importer: importer)

    l = o.order_lines.create! product: product
    l.update_custom_value! dest_cd, "DEST1"
    l.update_custom_value! div_cd, "DIV1"

    o
  }

  let(:order2) {
    dest_cd = custom_defintions[:ord_line_destination_code]
    div_cd = custom_defintions[:ord_line_division]

    o = FactoryBot(:order, importer: importer)
    l = o.order_lines.create! product: product
    l.update_custom_value! dest_cd, "DEST2"
    l.update_custom_value! div_cd, "DIV2"

    o
  }

  let(:importer) {
    i = with_customs_management_id(FactoryBot(:importer), "PVHWSHT")
    i.addresses.create! name: "DEST1", line_1: "ADDR1", city: "CITY", state: "ST", postal_code: "12345", phone_number: "123-456-7890", fax_number: "098-765-4321"
    i
  }
  let (:lading_port) { FactoryBot(:port, name: "lading_port")}
  let (:unlading_port) { FactoryBot(:port, name: "unlading_port")}

  let (:entry) {
    e = FactoryBot(:entry, customer_number: "PVHWSHT", importer: importer, master_bills_of_lading: "ABC", broker_reference: "REF", vessel: "VESS", voyage: "123", location_of_goods_description: "TERMINAL", carrier_code: "CODE", arrival_date: DateTime.new(2016, 02, 16, 12, 00), export_country_codes: "CN", lading_port: lading_port, unlading_port: unlading_port, carrier_name: "CARRIER NAME")
    e.containers.create! container_number: "12345", container_size: "20'", size_description: "DRY VAN", seal_number: "SEAL123", weight: 10, quantity: 20
    e.containers.create! container_number: "67890", container_size: "40", size_description: "HIGH Cube", seal_number: "SEAL345", weight: 10, quantity: 30
    e.commercial_invoices.create! invoice_number: "INV1"
    e.commercial_invoices.create! invoice_number: "INV2"

    e
  }

  let (:shipment) {
    # Create lines that link to each destination from the order and each container from the entry
    priority_cd = custom_defintions[:shpln_priority]
    inv_cd = custom_defintions[:shpln_invoice_number]

    s = FactoryBot(:shipment, importer: importer, master_bill_of_lading: "ABC")
    s.update_custom_value! priority_cd, "HOT"
    s.master_bill_of_lading = "ABC"

    cont1 = s.containers.create! container_number: "12345"
    cont2 = s.containers.create! container_number: "67890"

    line1 = s.shipment_lines.create! carton_qty: 10, product: product, container: cont1
    line1.update_custom_value! inv_cd, "INV1"
    line1.update_custom_value! priority_cd, "HOT"
    ps = line1.piece_sets.create! order_line: order1.order_lines.first, quantity: 10

    line2 = s.shipment_lines.create! carton_qty: 20, product: product, container: cont2
    line2.update_custom_value! inv_cd, "INV2"
    ps = line2.piece_sets.create! order_line: order2.order_lines.first, quantity: 20

    s
  }

  describe "generate_delivery_order_data" do

    def validate_base del, air_shipment = false
      expect(del.date).to eq Time.zone.now.in_time_zone("America/New_York").to_date
      expect(del.vfi_reference).to eq "REF"
      if air_shipment
        expect(del.vessel_voyage).to eq "CODE FLT: 123"
        expect(del.importing_carrier).to eq "CARRIER NAME"
      else
        expect(del.vessel_voyage).to eq "VESS V123"
        expect(del.importing_carrier).to eq "CODE"
      end
      expect(del.freight_location).to eq "TERMINAL"
      expect(del.port_of_origin).to eq lading_port.name

      expect(del.arrival_date).to eq Date.new(2016, 2, 16)
      expect(del.instruction_provided_by).to eq ["PVH CORP", "200 MADISON AVE", "NEW YORK, NY 10016-3903"]
      expect(del.body[0..2]).to eq ["PORT OF DISCHARGE: #{unlading_port.name}", "REFERENCE: CNREF", ""]
    end

    it "returns all delivery order data" do
      shipment
      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 2

      del = delivery_orders.first
      validate_base del

      expect(del.tab_title).to eq "DEST1"
      expect(del.no_cartons).to eq "10 CTNS"
      expect(del.for_delivery_to).to eq ["PVH CORP", "ADDR1", "CITY, ST 12345", "PH: 123-456-7890 FAX: 098-765-4321"]
      expect(del.body[4]).to eq "10 CTNS **HOT** 12345 20' SEAL# SEAL123 22 LBS"
      expect(del.body[5]).to eq "DIVISION DIV1 - 10 CTNS"
      expect(del.body[6]).to eq "B/L# ABC"
      expect(del.weight).to eq "22 LBS"

      del = delivery_orders.second
      expect(del.tab_title).to eq "DEST2"
      expect(del.no_cartons).to eq "20 CTNS"
      expect(del.for_delivery_to).to eq ["DEST2"]
      expect(del.body[4]).to eq "20 CTNS 67890 40'HC SEAL# SEAL345 22 LBS"
      expect(del.body[5]).to eq "DIVISION DIV2 - 20 CTNS"
      expect(del.body[6]).to eq "B/L# ABC"
      expect(del.weight).to eq "22 LBS"
    end

    it "handles all data on a single delivery order" do
      shipment
      order2.order_lines.first.update_custom_value! custom_defintions[:ord_line_destination_code], "DEST1"

      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 1

      del = delivery_orders.first
      validate_base del

      expect(del.tab_title).to eq "DEST1"
      expect(del.no_cartons).to eq "30 CTNS"
      expect(del.for_delivery_to).to eq ["PVH CORP", "ADDR1", "CITY, ST 12345", "PH: 123-456-7890 FAX: 098-765-4321"]
      expect(del.body[4]).to eq "10 CTNS **HOT** 12345 20' SEAL# SEAL123 22 LBS"
      expect(del.body[5]).to eq "DIVISION DIV1 - 10 CTNS"
      expect(del.body[6]).to eq "B/L# ABC"
      expect(del.body[7]).to eq ""
      expect(del.body[8]).to eq "20 CTNS 67890 40'HC SEAL# SEAL345 22 LBS"
      expect(del.body[9]).to eq "DIVISION DIV2 - 20 CTNS"
      expect(del.body[10]).to eq "B/L# ABC"
      expect(del.weight).to eq "44 LBS"
    end

    it "shows at most 16 container lines on a single delivery order" do
      shipment
      order_line = order1.order_lines.first
      inv_cd = custom_defintions[:shpln_invoice_number]

      container = shipment.containers.create! container_number: "ABC123"
      line = shipment.shipment_lines.create! carton_qty: 30, product: product, container: container
      line.update_custom_value! inv_cd, "INV1"
      ps = line.piece_sets.create! order_line: order_line, quantity: 30

      container = shipment.containers.create! container_number: "DEF123"
      line = shipment.shipment_lines.create! carton_qty: 40, product: product, container: container
      line.update_custom_value! inv_cd, "INV1"
      ps = line.piece_sets.create! order_line: order_line, quantity: 40

      container = shipment.containers.create! container_number: "HIJ123"
      line = shipment.shipment_lines.create! carton_qty: 50, product: product, container: container
      line.update_custom_value! inv_cd, "INV1"
      ps = line.piece_sets.create! order_line: order_line, quantity: 50

      entry.containers.create! container_number: "ABC123", container_size: "40", size_description: "DRY VAN", seal_number: "SEAL678", weight: 10
      entry.containers.create! container_number: "DEF123", container_size: "45", size_description: "HIGH Cube", seal_number: "SEAL789", weight: 10
      entry.containers.create! container_number: "HIJ123", container_size: "40", size_description: "DRY VAN", seal_number: "SEAL890", weight: 10

      # Put all the lines going to a single destination so, we make sure the only new delivery orders created are due to the container split
      order2.order_lines.first.update_custom_value! custom_defintions[:ord_line_destination_code], "DEST1"

      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 2

      del = delivery_orders.first
      validate_base del

      expect(del.tab_title).to eq "DEST1"
      expect(del.no_cartons).to eq "100 CTNS"
      expect(del.for_delivery_to).to eq ["PVH CORP", "ADDR1", "CITY, ST 12345", "PH: 123-456-7890 FAX: 098-765-4321"]
      expect(del.body[4]).to eq "10 CTNS **HOT** 12345 20' SEAL# SEAL123 22 LBS"
      expect(del.body[5]).to eq "DIVISION DIV1 - 10 CTNS"
      expect(del.body[6]).to eq "B/L# ABC"
      expect(del.body[7]).to eq ""
      expect(del.body[8]).to eq "20 CTNS 67890 40'HC SEAL# SEAL345 22 LBS"
      expect(del.body[9]).to eq "DIVISION DIV2 - 20 CTNS"
      expect(del.body[10]).to eq "B/L# ABC"
      expect(del.body[11]).to eq ""
      expect(del.body[12]).to eq "30 CTNS ABC123 40' SEAL# SEAL678 22 LBS"
      expect(del.body[13]).to eq "DIVISION DIV1 - 30 CTNS"
      expect(del.body[14]).to eq "B/L# ABC"
      expect(del.body[15]).to eq ""
      expect(del.body[16]).to eq "40 CTNS DEF123 45'HC SEAL# SEAL789 22 LBS"
      expect(del.body[17]).to eq "DIVISION DIV1 - 40 CTNS"
      expect(del.body[18]).to eq "B/L# ABC"
      expect(del.weight).to eq "88 LBS"


      del = delivery_orders.second
      expect(del.tab_title).to eq "DEST1 (2)"
      expect(del.no_cartons).to eq "50 CTNS"
      expect(del.for_delivery_to).to eq ["PVH CORP", "ADDR1", "CITY, ST 12345", "PH: 123-456-7890 FAX: 098-765-4321"]
      expect(del.body[4]).to eq "50 CTNS HIJ123 40' SEAL# SEAL890 22 LBS"
      expect(del.body[5]).to eq "DIVISION DIV1 - 50 CTNS"
      expect(del.body[6]).to eq "B/L# ABC"
      expect(del.weight).to eq "22 LBS"
    end

    it "splits divisions across multiple lines if more than 75 characters are used" do
      # Update the divisions to be really long values (50 chars each), then put both lines in the same container,
      # this will force the code to split the division ctn counts to be printed on their own lines
      container = shipment.shipment_lines.first.container
      shipment.shipment_lines.second.update_attributes! container: container

      div_cd = custom_defintions[:ord_line_division]
      dest_cd = custom_defintions[:ord_line_destination_code]
      order1.order_lines.first.update_custom_value!(div_cd, "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
      order2.order_lines.first.update_custom_value!(div_cd, "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY")
      order2.order_lines.first.update_custom_value!(dest_cd, "DEST1")
      shipment.reload

      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 1

      del = delivery_orders.first
      expect(del.body[4]).to eq "30 CTNS **HOT** 12345 20' SEAL# SEAL123 22 LBS"
      expect(del.body[5]).to eq "DIVISION XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX - 10 CTNS"
      expect(del.body[6]).to eq "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY - 20 CTNS"
      expect(del.body[7]).to eq "B/L# ABC"
    end

    it "matches entry to shipment with house bill" do
      entry.update_attributes! house_bills_of_lading: "ABC", master_bills_of_lading: ""

      shipment
      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 2
    end

    it "generates data from entry data when no shipments are found to match to" do
      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 1
      del = delivery_orders.first
      validate_base(del)
      expect(del.tab_title).to eq "PVH"
      expect(del.bill_of_lading).to eq "ABC"
      expect(del.weight).to eq "44 LBS"
      expect(del.no_cartons).to eq "50 CTNS"

      expect(del.body[4]).to eq "20 CTNS 12345 20' SEAL# SEAL123 22 LBS"
      expect(del.body[5]).to eq "DIVISION "
      expect(del.body[6]).to eq "B/L# ABC"
      expect(del.body[7]).to eq ""
      expect(del.body[8]).to eq "30 CTNS 67890 40'HC SEAL# SEAL345 22 LBS"
      expect(del.body[9]).to eq "DIVISION "
      expect(del.body[10]).to eq "B/L# ABC"
    end

    it "generates data for air shipments" do
      entry.containers.destroy_all
      entry.update_attributes! house_bills_of_lading: "HAWB", gross_weight: 10, total_packages: 20, transport_mode_code: "40"

      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 1
      del = delivery_orders.first
      validate_base(del, true)
      expect(del.tab_title).to eq "PVH"
      expect(del.bill_of_lading).to eq "MAWB: ABC"
      expect(del.weight).to eq "22 LBS"
      expect(del.no_cartons).to eq "20 CTNS"

      expect(del.body[4]).to eq "20 CTNS 22 LBS"
      expect(del.body[5]).to eq "DIVISION "
      expect(del.body[6]).to eq "HOUSE BILL# HAWB"
    end

    it "generates data for LCL shipments" do
      entry.update_attributes! house_bills_of_lading: "HAWB", gross_weight: 10, total_packages: 20, transport_mode_code: "10", fcl_lcl: "LCL"

      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.size).to eq 1
      del = delivery_orders.first
      validate_base(del)
      expect(del.tab_title).to eq "PVH"
      expect(del.bill_of_lading).to eq "ABC"
      expect(del.weight).to eq "44 LBS"
      expect(del.no_cartons).to eq "50 CTNS"

      expect(del.body[3]).to eq "LCL"
      expect(del.body[4]).to eq "20 CTNS 12345 20' SEAL# SEAL123 22 LBS"
      expect(del.body[5]).to eq "DIVISION "
      expect(del.body[6]).to eq "HOUSE BILL# HAWB"
      expect(del.body[7]).to eq ""
      expect(del.body[8]).to eq "30 CTNS 67890 40'HC SEAL# SEAL345 22 LBS"
      expect(del.body[9]).to eq "DIVISION "
      expect(del.body[10]).to eq "HOUSE BILL# HAWB"
    end

    it "handles really long tab names" do
      importer.addresses.first.update_attributes! name: "1234567890123456789012345678901234567890"

      # Generate enough data so it overflows to a second sheet
      shipment
      order_line = order1.order_lines.first
      inv_cd = custom_defintions[:shpln_invoice_number]

      container = shipment.containers.create! container_number: "ABC123"
      line = shipment.shipment_lines.create! carton_qty: 30, product: product, container: container
      line.update_custom_value! inv_cd, "INV1"
      ps = line.piece_sets.create! order_line: order_line, quantity: 30

      container = shipment.containers.create! container_number: "DEF123"
      line = shipment.shipment_lines.create! carton_qty: 40, product: product, container: container
      line.update_custom_value! inv_cd, "INV1"
      ps = line.piece_sets.create! order_line: order_line, quantity: 40

      container = shipment.containers.create! container_number: "HIJ123"
      line = shipment.shipment_lines.create! carton_qty: 50, product: product, container: container
      line.update_custom_value! inv_cd, "INV1"
      ps = line.piece_sets.create! order_line: order_line, quantity: 50

      entry.containers.create! container_number: "ABC123", container_size: "40", size_description: "DRY VAN", seal_number: "SEAL678", weight: 10
      entry.containers.create! container_number: "DEF123", container_size: "45", size_description: "HIGH Cube", seal_number: "SEAL789", weight: 10
      entry.containers.create! container_number: "HIJ123", container_size: "40", size_description: "DRY VAN", seal_number: "SEAL890", weight: 10

      # Put all the lines going to a single destination so, we make sure the only new delivery orders created are due to the container split
      order1.order_lines.first.update_custom_value! custom_defintions[:ord_line_destination_code], "1234567890123456789012345678901234567890"
      order2.order_lines.first.update_custom_value! custom_defintions[:ord_line_destination_code], "1234567890123456789012345678901234567890"

      delivery_orders = subject.generate_delivery_order_data entry
      expect(delivery_orders.length).to eq 2

      expect(delivery_orders.first.tab_title).to eq "123456789012345678901234567890"
      expect(delivery_orders.second.tab_title).to eq "12345678901234567890123456 (2)"
    end
  end
end