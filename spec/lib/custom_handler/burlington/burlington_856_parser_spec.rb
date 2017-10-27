require 'spec_helper'

describe OpenChain::CustomHandler::Burlington::Burlington856Parser do

  describe "process_transaction" do

    let (:importer) { Factory(:importer, system_code: "BURLI") }
    let (:cdefs) { subject.cdefs }
    let (:user) { Factory(:user) }
    

    context "standard_order" do
      let (:edi_data) { IO.read 'spec/fixtures/files/burlington_856.edi' }
      let (:segments) { REX12::Document.parse edi_data }
      let! (:order_1) {
        o = Factory(:order, order_number: "BURLI-365947702", importer: importer)
        ol = o.order_lines.create! product: product, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "13347530"

        o
      }
      
      let! (:order_2) {
        o = Factory(:order, order_number: "BURLI-364985401", importer: importer)
        ol = o.order_lines.create! product: product, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "13347530"

        o
      }

      let (:product) {
        p = Factory(:product, unique_identifier: "BURLI-PART1")
      }

      let! (:port_lading) { Port.create! unlocode: "HKHKG", name: "HONG KONG" }
      let! (:port_entry) { Port.create! unlocode: "USLGB", name: "Long Beach" }
      let! (:port_destination) { Port.create! unlocode: "USCHI", name: "Chicago" }
      let! (:port_unlading) { Port.create! unlocode: "USORD", name: "O'Hare" }

      it "parses edi segments into shipments" do
        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.reference).to eq "BURLI-146021201-02"
        expect(shipment.importer_reference).to eq "146021201-02"
        expect(shipment.last_exported_from_source).to eq Time.zone.parse("201701131737")
        expect(shipment.last_file_bucket).to eq "bucket"
        expect(shipment.last_file_path).to eq "file.edi"
        expect(shipment.departure_date).to eq Date.new(2017, 1, 8)
        expect(shipment.est_delivery_date).to eq Date.new(2017, 1, 9)
        expect(shipment.est_arrival_port_date).to eq Date.new(2017, 1, 10)
        expect(shipment.est_inland_port_date).to eq Date.new(2017, 1, 11)
        expect(shipment.master_bill_of_lading).to eq "CMDUQDAC023343"
        expect(shipment.house_bill_of_lading).to eq "PRO-NUMBER"
        expect(shipment.mode).to eq "Consolidation"
        expect(shipment.vessel_carrier_scac).to eq "CMDU"
        expect(shipment.number_of_packages_uom).to eq "CTN"
        expect(shipment.number_of_packages).to eq 3
        expect(shipment.gross_weight).to eq 10057
        expect(shipment.lading_port).to eq port_lading
        expect(shipment.entry_port).to eq port_entry
        expect(shipment.destination_port).to eq port_destination
        expect(shipment.unlading_port).to eq port_unlading

        expect(shipment.containers.length).to eq 1
        container = shipment.containers.first
        expect(container.container_number).to eq "HJMU1543751"
        expect(container.seal_number).to eq "SEAL#"

        expect(shipment.shipment_lines.length).to eq 2
        line = shipment.shipment_lines.first

        expect(line.container).to eq container
        expect(line.product).to eq product
        expect(line.order_lines.first).to eq order_1.order_lines.first
        expect(line.quantity).to eq 2
        expect(line.carton_qty).to eq 2
        expect(line.gross_kgs).to eq 6412

        line = shipment.shipment_lines.second

        expect(line.container).to eq container
        expect(line.product).to eq product
        expect(line.order_lines.first).to eq order_2.order_lines.first
        expect(line.quantity).to eq 1
        expect(line.carton_qty).to eq 1
        expect(line.gross_kgs).to eq 3645

        expect(shipment.entity_snapshots.length).to eq 1
        snap = shipment.entity_snapshots.first
        expect(snap.user).to eq user
        expect(snap.context).to eq "file.edi"
      end

      it "matches to order on SKU # if item numbers don't match" do
        ol = order_1.order_lines.first
        ol.update_attributes! sku: "13347530"
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "BIN12312"

        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.shipment_lines.length).to eq 2
        expect(shipment.shipment_lines.first.order_lines.first).to eq order_1.order_lines.first
      end

      it "uses UPC (UP) from EDI if Item Number (IN) is not sent" do
        edi_data.gsub! "LIN||IN|13347530", "LIN||UP|13347530"

        ol = order_1.order_lines.first
        ol.update_attributes! sku: "13347530"
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "BIN12312"

        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.shipment_lines.length).to eq 2
        expect(shipment.shipment_lines.first.order_lines.first).to eq order_1.order_lines.first
      end

      it "leaves missing port codes blank" do
        port_unlading.destroy

        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment.unlading_port).to be_nil
      end

      it "errors on missing order" do
        order_1.destroy

        expect { subject.process_transaction user, segments, bucket: "bucket", file: "file.edi" }.to raise_error described_class::EdiBusinessLogicError, "Burlington 856 references missing Order # '365947702'."
      end

      it "errors on missing order line" do
        order_1.order_lines.destroy_all

        expect { subject.process_transaction user, segments, bucket: "bucket", file: "file.edi" }.to raise_error described_class::EdiBusinessLogicError, "Burlington 856 references missing Order Line from Order '365947702' with Buyer Item Number / UPC '13347530'."
      end

      it "errors on missing importer" do
        importer.destroy

        expect { subject.process_transaction user, segments, bucket: "bucket", file: "file.edi" }.to raise_error "Unable to find Burlington importer account with system code of: 'BURLI'."
      end

      it "converts LB gross weight to KG" do
        edi_data.gsub!("|KG", "|LB")

        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment.gross_weight).to eq BigDecimal("4561.77")

        line = shipment.shipment_lines.first
        expect(line.gross_kgs).to eq BigDecimal("2908.43")

        line = shipment.shipment_lines.second
        expect(line.gross_kgs).to eq BigDecimal("1653.34")
      end
    end

    context "prepack_order" do
      let (:segments) { REX12::Document.parse IO.read 'spec/fixtures/files/burlington_prepack_856.edi'}
      let! (:order_1) {
        o = Factory(:order, order_number: "BURLI-641585114", importer: importer)
        ol = o.order_lines.create! product: product_1, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150180"

        ol = o.order_lines.create! product: product_2, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150203"

        ol = o.order_lines.create! product: product_3, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150229"

        o
      }
      
      let (:product_1) {
        p = Factory(:product, unique_identifier: "BURLI-PART1")
      }

      let (:product_2) {
        p = Factory(:product, unique_identifier: "BURLI-PART2")
      }

      let (:product_3) {
        p = Factory(:product, unique_identifier: "BURLI-PART3")
      }

      it "parses edi segments into shipments" do
        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.number_of_packages_uom).to eq "CTN"
        expect(shipment.number_of_packages).to eq 2
        expect(shipment.gross_weight).to eq 1230

        expect(shipment.containers.length).to eq 1
        container = shipment.containers.first

        expect(shipment.shipment_lines.length).to eq 3

        line = shipment.shipment_lines.first
        expect(line.container).to eq container
        expect(line.product).to eq product_1
        expect(line.order_lines.first).to eq order_1.order_lines.first
        expect(line.quantity).to eq 8
        expect(line.carton_qty).to eq 2
        expect(line.gross_kgs).to eq 410

        line = shipment.shipment_lines.second
        expect(line.container).to eq container
        expect(line.product).to eq product_2
        expect(line.order_lines.first).to eq order_1.order_lines.second
        expect(line.quantity).to eq 8
        # Carton quantity is zero on all lines but the first because technically the 3 lines from
        # the same prepack item HL loop are all in the same carton
        expect(line.carton_qty).to eq 0
        expect(line.gross_kgs).to eq 410

        line = shipment.shipment_lines[2]
        expect(line.container).to eq container
        expect(line.product).to eq product_3
        expect(line.order_lines.first).to eq order_1.order_lines[2]
        expect(line.quantity).to eq 8
        # Carton quantity is zero on all lines but the first because technically the 3 lines from
        # the same prepack item HL loop are all in the same carton
        expect(line.carton_qty).to eq 0
        expect(line.gross_kgs).to eq 410
      end
    end

    context "with alernate loop structure" do
      let (:segments) { REX12::Document.parse IO.read 'spec/fixtures/files/burlington_856_alternate_loop.edi'}
      let! (:order_1) {
        o = Factory(:order, order_number: "BURLI-365947702", importer: importer)
        ol = o.order_lines.create! product: product_1, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "13347530"

        ol = o.order_lines.create! product: product_2, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "13347531"
        o
      }
      
      let (:product_1) {
        p = Factory(:product, unique_identifier: "BURLI-PART1")
      }

      let (:product_2) {
        p = Factory(:product, unique_identifier: "BURLI-PART2")
      }

      it "parses alternate edi loop structure" do
        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.number_of_packages_uom).to eq "CTN"
        expect(shipment.number_of_packages).to eq 4
        expect(shipment.gross_weight).to eq 6412

        expect(shipment.shipment_lines.length).to eq 2

        line = shipment.shipment_lines.first
        expect(line.product).to eq product_1
        expect(line.order_lines.first).to eq order_1.order_lines.first
        expect(line.quantity).to eq 2
        expect(line.carton_qty).to eq 2
        expect(line.gross_kgs).to eq 3206

        line = shipment.shipment_lines.second
        expect(line.product).to eq product_2
        expect(line.order_lines.first).to eq order_1.order_lines.second
        expect(line.quantity).to eq 2
        # Carton quantity is zero on all lines but the first because technically the 3 lines from
        # the same prepack item HL loop are all in the same carton
        expect(line.carton_qty).to eq 2
        expect(line.gross_kgs).to eq 3206
      end
    end

    context "with alernate loop structure" do
      let (:segments) { REX12::Document.parse IO.read 'spec/fixtures/files/burlington_856_alternate_prepack_loop.edi'}
      let! (:order_1) {
        o = Factory(:order, order_number: "BURLI-365947702", importer: importer)
        ol = o.order_lines.create! product: product_1, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150180"

        ol = o.order_lines.create! product: product_2, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150203"
        o
      }
      
      let (:product_1) {
        p = Factory(:product, unique_identifier: "BURLI-PART1")
      }

      let (:product_2) {
        p = Factory(:product, unique_identifier: "BURLI-PART2")
      }

      it "parses alternate edi loop prepack structure" do
        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.number_of_packages_uom).to eq "CTN"
        expect(shipment.number_of_packages).to eq 4
        expect(shipment.gross_weight).to eq 6412

        expect(shipment.shipment_lines.length).to eq 2

        line = shipment.shipment_lines.first
        expect(line.product).to eq product_1
        expect(line.order_lines.first).to eq order_1.order_lines.first
        expect(line.quantity).to eq 8
        expect(line.carton_qty).to eq 4
        expect(line.gross_kgs).to eq 3206

        line = shipment.shipment_lines.second
        expect(line.product).to eq product_2
        expect(line.order_lines.first).to eq order_1.order_lines.second
        expect(line.quantity).to eq 8
        # Carton quantity is zero on all lines but the first because technically the 3 lines from
        # the same prepack item HL loop are all in the same carton
        expect(line.carton_qty).to eq 0
        expect(line.gross_kgs).to eq 3206
      end
    end

    context "with prepacks missing SLN segments" do
      let (:segments) { REX12::Document.parse IO.read 'spec/fixtures/files/burlington_prepack_856_missing_sln.edi'}
      let! (:order) {
        o = Factory(:order, order_number: "BURLI-641585114", importer: importer)
        ol = o.order_lines.create! product: product_1, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_outer_pack_identifier], "PO6415851LN14"
        ol.update_custom_value! cdefs[:ord_line_units_per_inner_pack], 4
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150180"

        ol = o.order_lines.create! product: product_2, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_outer_pack_identifier], "PO6415851LN14"
        ol.update_custom_value! cdefs[:ord_line_units_per_inner_pack], 4
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150181"

        ol = o.order_lines.create! product: product_3, quantity: 100
        ol.update_custom_value! cdefs[:ord_line_outer_pack_identifier], "PO6415851LN14"
        ol.update_custom_value! cdefs[:ord_line_units_per_inner_pack], 4
        ol.update_custom_value! cdefs[:ord_line_buyer_item_number], "16150182"

        o
      }
      
      let (:product_1) {
        p = Factory(:product, unique_identifier: "BURLI-PART1")
        p.update_custom_value! cdefs[:prod_part_number], "16150180"
        p
      }

      let (:product_2) {
        p = Factory(:product, unique_identifier: "BURLI-PART2")
        p.update_custom_value! cdefs[:prod_part_number], "16150181"
        p
      }

      let (:product_3) {
        p = Factory(:product, unique_identifier: "BURLI-PART3")
        p.update_custom_value! cdefs[:prod_part_number], "16150182"
        p
      }

      it "parses edi" do
        shipment = subject.process_transaction user, segments, bucket: "bucket", file: "file.edi"
        expect(shipment).not_to be_nil

        expect(shipment.number_of_packages_uom).to eq "CTN"
        expect(shipment.number_of_packages).to eq 2
        expect(shipment.gross_weight).to eq 1230

        expect(shipment.shipment_lines.length).to eq 3

        line = shipment.shipment_lines.first
        expect(line.product).to eq product_1
        expect(line.order_lines.first).to eq order.order_lines.first
        expect(line.quantity).to eq 8
        expect(line.carton_qty).to eq 2
        expect(line.gross_kgs).to eq 410

        line = shipment.shipment_lines.second
        expect(line.product).to eq product_2
        expect(line.order_lines.first).to eq order.order_lines.second
        expect(line.quantity).to eq 8
        # Carton quantity is zero on all lines but the first because technically the 3 lines from
        # the same prepack item HL loop are all in the same carton
        expect(line.carton_qty).to eq 0
        expect(line.gross_kgs).to eq 410

        line = shipment.shipment_lines[2]
        expect(line.product).to eq product_3
        expect(line.order_lines.first).to eq order.order_lines[2]
        expect(line.quantity).to eq 8
        # Carton quantity is zero on all lines but the first because technically the 3 lines from
        # the same prepack item HL loop are all in the same carton
        expect(line.carton_qty).to eq 0
        expect(line.gross_kgs).to eq 410
      end

      it "raises an error if order line is not found" do
        order.order_lines.destroy_all
        expect { subject.process_transaction user, segments, bucket: "bucket", file: "file.edi" }.to raise_error described_class::EdiBusinessLogicError, "Burlington 856 references missing Order Line from Order '641585114' with Outer Pack Identifier 'PO6415851LN14'."
      end

      it "raises an error if order is not found" do
        order.destroy
        expect { subject.process_transaction user, segments, bucket: "bucket", file: "file.edi" }.to raise_error described_class::EdiBusinessLogicError, "Burlington 856 references missing Order # '641585114'."
      end
    end
  end

  describe "integration_folder" do
    subject { described_class }
    
    it "uses correct integration folder path" do
      expect(subject.integration_folder).to eq "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_burlington_856"
    end
  end

end