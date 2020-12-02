describe OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser do

  let!(:inbound_file) do
    f = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return f
    f
  end

  describe "process_file" do
    let(:file_data) { IO.read('spec/fixtures/files/target_entry_initiation.txt') }

    let (:cdefs) { subject.send(:cdefs) }
    let (:assortment_product) do
      p = create(:product, unique_identifier: "032020738-106879518")
      p.update_custom_value! cdefs[:prod_type], "Assortment"
      p
    end
    let (:us) { create(:country, iso_code: "US") }
    let (:xvv_product) do
      p = create(:product, unique_identifier: "032020738-106879518")
      p.update_custom_value! cdefs[:prod_type], "Set"
      c = p.classifications.create! country: us
      t = c.tariff_records.create! hts_1: "7323930045"
      t.update_custom_value! cdefs[:tar_xvv], "X"

      t = c.tariff_records.create! hts_1: "7323930045"
      t.update_custom_value! cdefs[:tar_xvv], "V"

      t = c.tariff_records.create! hts_1: "8215995000"
      t.update_custom_value! cdefs[:tar_xvv], "V"

      p
    end

    def expect_date(s, code, date)
      shipment_date = s.dates.find {|d| d.code == code}
      expect(shipment_date).not_to be_nil, -> { "expected to find #{code} date in shipment."}
      expect(shipment_date.date).to eq date
    end

    it "processes an entry initiation file" do
      now = Time.zone.now
      shipments = nil
      Timecop.freeze(now) { shipments = subject.process_file file_data }

      expect(shipments.length).to eq 1

      s = shipments.first
      expect(s.customer).to eq "TEST"
      expect(s.customs_ship_mode).to eq 11
      expect(s.vessel).to eq "YM UNISON"
      expect(s.voyage).to eq "084E"
      expect(s.lading_port).to eq "55206"
      expect(s.unlading_port).to eq "3002"
      expect(s.entry_port).to eq "3002"
      expect_date(s, :export_date, Date.new(2019, 12, 3))
      expect_date(s, :est_arrival_date, Date.new(2019, 12, 19))
      expect_date(s, :arrival_date, Date.new(2019, 12, 19))
      expect_date(s, :import_date, Date.new(2019, 12, 19))
      # Charges should be moved down to the invoice
      expect(s.charges).to be_nil
      expect(s.carrier).to eq "YMLU"
      expect(s.weight_kg).to eq 13_271
      expect(s.recon_value_flag).to eq true
      expect(s.country_of_export).to be_nil

      expect(s.bills_of_lading.length).to eq 1
      bol = s.bills_of_lading.first
      expect(bol.master_bill).to eq "YMLUW490360331"
      # Because the master bill is repeated...we don't expect a house bill to be present
      expect(bol.house_bill).to be_nil

      expect(s.containers.length).to eq 2
      expect(s.containers.first.container_number).to eq "TGBU6451898"
      expect(s.containers.second.container_number).to eq "YMLU8645801"

      expect(s.invoices.length).to eq 1
      i = s.invoices.first

      expect(i.invoice_number).to eq "YMLUW490360331"
      expect(i.charges).to eq 1.234
      expect(i.invoice_date).to eq now.in_time_zone("America/New_York").to_date

      expect(i.invoice_lines.length).to eq 2

      l = i.invoice_lines.first
      expect(l.department).to eq "0032"
      expect(l.po_number).to eq "2663814"
      expect(l.part_number).to eq "032020738-106879518"
      expect(l.cartons).to eq 101
      expect(l.pieces).to eq 101
      expect(l.pieces_uom).to be_nil # Verify the default generated by the xml generator will be used
      expect(l.unit_price).to eq BigDecimal("119.545")
      expect(l.foreign_value).to eq BigDecimal("12074.05")
      expect(l.country_of_origin).to be_nil
      expect(l.country_of_export).to eq "VN"
      expect(l.container_number).to eq "TGBU6451898"

      l = i.invoice_lines.second
      expect(l.department).to eq "0032"
      expect(l.po_number).to eq "2663814"
      expect(l.part_number).to eq "032020739-106879518"
      expect(l.cartons).to eq 300
      expect(l.pieces).to eq 300
      expect(l.unit_price).to eq BigDecimal("81.744")
      expect(l.foreign_value).to eq BigDecimal("24523.20")
      expect(l.country_of_origin).to be_nil
      expect(l.country_of_export).to eq "VN"
      expect(l.container_number).to eq "YMLU8645801"

      expect(inbound_file).to have_identifier(:master_bill, "YMLUW490360331")
      expect(inbound_file).to have_identifier(:po_number, "2663814")
    end

    it "uses proper customer number in production" do
      ms = stub_master_setup
      expect(ms).to receive(:production?).and_return true

      shipments = subject.process_file file_data

      expect(shipments.length).to eq 1

      s = shipments.first
      expect(s.customer).to eq "TARGEN"
    end

    it "handles assortments by sending PKG uom" do
      assortment_product
      shipments = subject.process_file file_data
      line = shipments.first.invoices.first.invoice_lines.first
      expect(line.pieces_uom).to eq "PKG"
    end

    it "handles XVV sets by exploding the components to individual invoice lines" do
      xvv_product
      shipments = subject.process_file file_data
      lines = shipments.first.invoices.first.invoice_lines
      # First 3 lines are the XVV part
      expect(lines.length).to eq 4

      line = lines[0]
      expect(line.part_number).to eq "032020738-106879518"
      expect(line.hts).to eq "7323930045"
      expect(line.spi2).to eq "X"

      line = lines[1]
      expect(line.part_number).to eq "032020738-106879518"
      expect(line.hts).to eq "7323930045"
      expect(line.spi2).to eq "V"

      line = lines[2]
      expect(line.part_number).to eq "032020738-106879518"
      expect(line.hts).to eq "8215995000"
      expect(line.spi2).to eq "V"
    end
  end

  describe "process_01" do
    let(:line) { "0112YMLUW490360331                YMLUW490360331                11YM UNISON                          084E-VN 5520630022019120320191219        1.234YMLU000013270.520001" } # rubocop:disable Layout/LineLength
    let(:shipment) do
      s = described_class::CiLoadEntry.new
      s.bills_of_lading = []
      s.dates = []
      s
    end

    it "parses house bill information for ocean if different than master" do
      line.sub!("YMLUW490360331", "MAEUXXXXXXXXXX")
      subject.process_01 shipment, line
      bol = shipment.bills_of_lading.first
      expect(bol.master_bill).to eq "YMLUW490360331"
      expect(bol.house_bill).to eq "MAEUXXXXXXXXXX"
    end

    it "parses air primary bill into house bill for air" do
      line[64, 2] = "40"
      subject.process_01 shipment, line
      bol = shipment.bills_of_lading.first
      expect(bol.master_bill).to be_nil
      expect(bol.house_bill).to eq "YMLUW490360331"
    end

    it "parses air master air waybill for air if numbers are different" do
      line[64, 2] = "40"
      line.sub!("YMLUW490360331", "MAEUXXXXXXXXXX")

      subject.process_01 shipment, line

      bol = shipment.bills_of_lading.first
      expect(bol.master_bill).to eq "YMLUW490360331"
      expect(bol.house_bill).to eq "MAEUXXXXXXXXXX"
    end

    it "leaves recon flag nil if not Y" do
      line[164, 3] = "000"
      subject.process_01 shipment, line
      expect(shipment.recon_value_flag).to be_nil
    end
  end

  describe "process_02" do
    let(:shipment) do
      s = described_class::CiLoadEntry.new
      s.containers = []
      s
    end
    let(:line) { "0212YMLUW490360331                TGBU6451898"}

    it "does nothing if container is blank" do
      line[34, 15] = "               "
      subject.process_02 shipment, line
      expect(shipment.containers.length).to eq 0
    end
  end

  describe "process_04" do
    let(:shipment) do
      s = described_class::CiLoadEntry.new
      s.invoices = []
      i = described_class::CiLoadInvoice.new
      i.invoice_lines = []
      s
    end
    let(:line) { "0412YMLUW490360331                0032-2663814106879518032020738101      1        101      000000119.545VN          0.0000.000TGBU6451898"}

    it "doesn't calculate line value if unit price is zero" do
      line[92, 13] = "0.00         "
      invoice_lines = subject.process_04 shipment, shipment.invoices.first, line

      expect(invoice_lines.first.foreign_value).to be_nil
    end

    it "doesn't calculate line value if piece count is zero" do
      line[82, 9] = "0        "
      invoice_lines = subject.process_04 shipment, shipment.invoices.first, line

      expect(invoice_lines.first.foreign_value).to be_nil
    end
  end

  describe "add_special_tariffs?" do
    it "returns false" do
      expect(subject.add_special_tariffs?(nil, nil, nil)).to eq false
    end
  end

  describe "parse (class-level)" do
    it "calls instance method" do
      file_data = instance_double("file_data")
      opts = instance_double("opts")

      expect(described_class).to receive(:new).and_return(subject)
      expect(subject).to receive(:parse).with(file_data, opts)

      described_class.parse file_data, opts
    end
  end

  describe "parse" do
    let(:file_data) { IO.read('spec/fixtures/files/target_entry_initiation.txt') }
    let(:cdefs) { subject.send(:cdefs) }
    let!(:target) { with_customs_management_id(Factory(:importer), "TARGEN") }
    let!(:country_us) { Factory(:country, iso_code: "US") }

    it "processes file data, makes and saves shipment and generates/sends XML" do
      port_lading = Factory(:port, schedule_k_code: "86420", name: "Lading Port")
      port_unlading = Factory(:port, schedule_d_code: "7531", name: "Unlading Port")
      country_export = Factory(:country, iso_code: "VN", name: "Vietnam")

      prod_1 = make_product("032-518", country_origin_iso: "CN")
      prod_2 = make_product("032-519", country_origin_iso: "IN")

      shp_obj = new_shipment
      shp_obj.vessel = "SS Minnow"
      shp_obj.voyage = "VOY9876"
      shp_obj.customs_ship_mode = 11
      shp_obj.unlading_port = "7531"
      shp_obj.lading_port = "86420"
      shp_obj.country_of_export = "VN"
      shp_obj.carrier = "CARR"
      shp_obj.recon_value_flag = true
      shp_obj.bills_of_lading << new_bol(master_bill: "MBMB20392039", house_bill: "HBHB10291029")
      shp_obj.dates << new_date(:export_date, Date.new(2020, 2, 20))
      shp_obj.dates << new_date(:est_arrival_date, Date.new(2021, 2, 21))
      shp_obj.containers << new_container("CONT12345")
      shp_obj.containers << new_container("CONT67890")

      inv_1 = new_invoice
      inv_1.invoice_lines << new_invoice_line(part_number: "032-518", po_number: "PO-X", unit_price: BigDecimal("3.25"), pieces: 5, cartons: 3)
      inv_1.invoice_lines << new_invoice_line(part_number: "032-518", po_number: "PO-X", unit_price: BigDecimal("3.25"), pieces: 6, cartons: 4)
      inv_1.invoice_lines << new_invoice_line(part_number: "032-519", po_number: "PO-X", unit_price: BigDecimal("5.47"), pieces: 7, cartons: 5)
      shp_obj.invoices << inv_1

      inv_2 = new_invoice
      inv_2.invoice_lines << new_invoice_line(part_number: "032-518", po_number: "PO-Y", unit_price: BigDecimal("6.58"), pieces: 8, cartons: 6)
      shp_obj.invoices << inv_2

      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).to receive(:generate_and_send_shipment_xml).with([shp_obj], sync_records: [kind_of(SyncRecord)])
      subject.parse file_data

      shp = Shipment.where(reference: "MBMB20392039", importer_id: target.id).first
      expect(shp).not_to be_nil
      expect(shp.vessel).to eq "SS Minnow"
      expect(shp.voyage).to eq "VOY9876"
      expect(shp.mode).to eq "Ocean"
      expect(shp.unlading_port).to eq port_unlading
      expect(shp.lading_port).to eq port_lading
      expect(shp.country_export).to eq country_export
      expect(shp.master_bill_of_lading).to eq "MBMB20392039"
      expect(shp.house_bill_of_lading).to eq "HBHB10291029"
      expect(shp.departure_date).to eq Date.new(2020, 2, 20)
      expect(shp.est_arrival_port_date).to eq Date.new(2021, 2, 21)
      expect(shp.vessel_carrier_scac).to eq "CARR"
      expect(shp.custom_value(cdefs[:shp_first_sale])).to eq true

      expect(shp.containers.length).to eq 2
      expect(shp.containers[0].container_number).to eq "CONT12345"
      expect(shp.containers[1].container_number).to eq "CONT67890"

      expect(shp.shipment_lines.length).to eq 3

      sl_1 = shp.shipment_lines[0]
      expect(sl_1.line_number).to eq 1
      expect(sl_1.quantity).to eq 11
      expect(sl_1.carton_qty).to eq 7
      expect(sl_1.product).to eq prod_1
      expect(sl_1.order_line.line_number).to eq 1
      expect(sl_1.order_line.country_of_origin).to eq "CN"
      expect(sl_1.order_line.price_per_unit).to eq BigDecimal("3.25")
      expect(sl_1.order_line.order.order_number).to eq "PO-X"
      expect(sl_1.order_line.order.importer_id).to eq target.id

      sl_2 = shp.shipment_lines[1]
      expect(sl_2.line_number).to eq 2
      expect(sl_2.quantity).to eq 7
      expect(sl_2.carton_qty).to eq 5
      expect(sl_2.product).to eq prod_2
      expect(sl_2.order_line.line_number).to eq 2
      expect(sl_2.order_line.country_of_origin).to eq "IN"
      expect(sl_2.order_line.price_per_unit).to eq BigDecimal("5.47")
      expect(sl_2.order_line.order.order_number).to eq "PO-X"
      expect(sl_2.order_line.order.importer_id).to eq target.id
      expect(sl_1.order_line.order).to eq sl_2.order_line.order

      sl_3 = shp.shipment_lines[2]
      expect(sl_3.line_number).to eq 3
      expect(sl_3.quantity).to eq 8
      expect(sl_3.carton_qty).to eq 6
      expect(sl_3.product).to eq prod_1
      expect(sl_3.order_line.line_number).to eq 1
      expect(sl_3.order_line.country_of_origin).to eq "CN"
      expect(sl_3.order_line.price_per_unit).to eq BigDecimal("6.58")
      expect(sl_3.order_line.order.order_number).to eq "PO-Y"
      expect(sl_3.order_line.order.importer_id).to eq target.id
      expect(sl_1.order_line.order).not_to eq sl_3.order_line.order

      sync_records = shp.sync_records.find_all { |sync| OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER == sync.trading_partner }
      expect(sync_records.length).to eq 1
      expect(sync_records[0].sent_at).not_to be_nil
      expect(sync_records[0].confirmed_at).not_to be_nil

      expect(inbound_file).to have_identifier(:shipment_number, "MBMB20392039", Shipment, shp.id)
      expect(inbound_file).to have_info_message("Shipment 'MBMB20392039' created.")
      expect(inbound_file).to have_no_warning_messages
    end

    def new_shipment
      s = described_class::CiLoadEntry.new
      s.invoices = []
      s.containers = []
      s.dates = []
      s.bills_of_lading = []
      s
    end

    def new_bol master_bill: nil, house_bill: nil
      b = described_class::CiLoadBillsOfLading.new
      b.master_bill = master_bill
      b.house_bill = house_bill
      b
    end

    def new_container container_number
      described_class::CiLoadContainer.new(container_number)
    end

    def new_date date_code, date
      described_class::CiLoadEntryDate.new(date_code, date)
    end

    def new_invoice
      i = described_class::CiLoadInvoice.new
      i.invoice_lines = []
      i
    end

    def new_invoice_line part_number: nil, po_number: nil, unit_price: nil, pieces: nil, cartons: nil
      il = described_class::CiLoadInvoiceLine.new
      il.part_number = part_number
      il.po_number = po_number
      il.unit_price = unit_price
      il.pieces = pieces
      il.cartons = cartons
      il
    end

    def make_product unique_identifier, country_origin_iso: nil
      prod = Factory(:product, unique_identifier: unique_identifier)
      if country_origin_iso
        us_class = prod.classifications.create! country: country_us
        tar = us_class.tariff_records.create!
        tar.find_and_set_custom_value(cdefs[:tar_country_of_origin], country_origin_iso)
        tar.save!
      end
      prod
    end

    it "raises an error when Target company cannot be found" do
      target.destroy!

      shp_obj = new_shipment
      shp_obj.bills_of_lading << new_bol(master_bill: "X")
      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).not_to receive(:generate_and_send_shipment_xml)

      expect { subject.parse file_data }.to raise_error "Target customer not found."
      expect(inbound_file).to have_error_message "Target customer not found."
    end

    it "handles multiple shipments" do
      shp_obj_1 = instance_double("ci_load_shipment_1")
      shp_obj_2 = instance_double("ci_load_shipment_2")
      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj_1, shp_obj_2]
      shp_1 = instance_double("shipment_1")
      shp_2 = instance_double("shipment_2")
      expect(subject).to receive(:make_shipment).with(shp_obj_1).and_return shp_1
      expect(subject).to receive(:make_shipment).with(shp_obj_2).and_return shp_2
      sync_1 = SyncRecord.new(trading_partner: "X")
      sync_2 = SyncRecord.new(trading_partner: "X")
      expect(SyncRecord).to receive(:find_or_build_sync_record)
        .with(shp_1, OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER)
        .and_return sync_1
      expect(SyncRecord).to receive(:find_or_build_sync_record)
        .with(shp_2, OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER)
        .and_return sync_2

      expect(subject).to receive(:generate_and_send_shipment_xml).with([shp_obj_1, shp_obj_2], sync_records: [sync_1, sync_2])

      subject.parse file_data

      expect(sync_1.sent_at).not_to be_nil
      expect(sync_2.confirmed_at).not_to be_nil
    end

    it "warns about missing product" do
      prod = make_product("032-519")

      shp_obj = new_shipment
      shp_obj.bills_of_lading << new_bol(master_bill: "MBMB20392039")

      inv = new_invoice
      inv.invoice_lines << new_invoice_line(part_number: "032-518", po_number: "PO-X", unit_price: BigDecimal("3.25"), pieces: 5, cartons: 3)
      inv.invoice_lines << new_invoice_line(part_number: "032-519", po_number: "PO-X", unit_price: BigDecimal("5.47"), pieces: 7, cartons: 5)
      shp_obj.invoices << inv

      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).to receive(:generate_and_send_shipment_xml).with([shp_obj], sync_records: [kind_of(SyncRecord)])
      subject.parse file_data

      shp = Shipment.where(reference: "MBMB20392039", importer_id: target.id).first
      # Only one line is added, the line with matching product, despite there being two lines in the source file.
      expect(shp.shipment_lines.length).to eq 1

      sl = shp.shipment_lines[0]
      expect(sl.line_number).to eq 1
      expect(sl.product).to eq prod
      expect(sl.quantity).to eq 7

      expect(inbound_file).to have_identifier(:shipment_number, "MBMB20392039", Shipment, shp.id)
      expect(inbound_file).to have_info_message("Shipment 'MBMB20392039' created.")
      expect(inbound_file).to have_warning_message("Product not found: Line-level information was not added to shipment 'MBMB20392039' for product '032-518'.")
    end

    it "raises error when US country not found" do
      country_us.destroy!

      make_product("032-519")

      shp_obj = new_shipment
      shp_obj.bills_of_lading << new_bol(master_bill: "MBMB20392039")

      inv = new_invoice
      inv.invoice_lines << new_invoice_line(part_number: "032-519", po_number: "PO-X", unit_price: BigDecimal("5.47"), pieces: 7, cartons: 5)
      shp_obj.invoices << inv

      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).not_to receive(:generate_and_send_shipment_xml)

      expect { subject.parse file_data }.to raise_error "No US country found."
      expect(inbound_file).to have_error_message "No US country found."
    end

    it "shows 'Air' as transport mode for air shipment" do
      shp_obj = new_shipment
      shp_obj.customs_ship_mode = 41
      shp_obj.bills_of_lading << new_bol(master_bill: "MBMB20392039")

      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).to receive(:generate_and_send_shipment_xml).with([shp_obj], sync_records: [kind_of(SyncRecord)])
      subject.parse file_data

      shp = Shipment.where(reference: "MBMB20392039", importer_id: target.id).first
      expect(shp.mode).to eq "Air"
    end

    it "shows nil as transport mode for non-air/sea shipment" do
      shp_obj = new_shipment
      shp_obj.customs_ship_mode = 31
      shp_obj.bills_of_lading << new_bol(master_bill: "MBMB20392039")

      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).to receive(:generate_and_send_shipment_xml).with([shp_obj], sync_records: [kind_of(SyncRecord)])
      subject.parse file_data

      shp = Shipment.where(reference: "MBMB20392039", importer_id: target.id).first
      expect(shp.mode).to be_nil
    end

    it "updates existing shipment" do
      prod_1 = make_product("032-518")
      prod_2 = make_product("032-519")

      ord_exist = Factory(:order, order_number: "PO-X", importer_id: target.id)
      ol_1 = ord_exist.order_lines.create! line_number: 2, product: prod_1
      ol_2 = ord_exist.order_lines.create! line_number: 3, product: prod_2

      # Existing lines and containers should be replaced.
      shp_exist = Factory(:shipment, reference: "MBMB20392039", importer_id: target.id)
      shp_exist.shipment_lines.create! line_number: 5, linked_order_line_id: ol_1.id, product: prod_1
      shp_exist.shipment_lines.create! line_number: 6, linked_order_line_id: ol_2.id, product: prod_2
      shp_exist.containers.create! container_number: "EXISTING"

      shp_obj = new_shipment
      shp_obj.bills_of_lading << new_bol(master_bill: "MBMB20392039", house_bill: "HBHB10291029")
      shp_obj.containers << new_container("CONT12345")
      shp_obj.containers << new_container("CONT67890")

      inv_1 = new_invoice
      inv_1.invoice_lines << new_invoice_line(part_number: "032-518", po_number: "PO-X", unit_price: BigDecimal("3.25"), pieces: 5, cartons: 3)
      shp_obj.invoices << inv_1

      expect(subject).to receive(:process_file).with(file_data).and_return [shp_obj]

      expect(subject).to receive(:generate_and_send_shipment_xml).with([shp_obj], sync_records: [kind_of(SyncRecord)])
      subject.parse file_data

      shp = Shipment.where(reference: "MBMB20392039", importer_id: target.id).first
      expect(shp.id).to eq shp_exist.id

      expect(shp.containers.length).to eq 2
      expect(shp.containers[0].container_number).to eq "CONT12345"
      expect(shp.containers[1].container_number).to eq "CONT67890"

      expect(shp.shipment_lines.length).to eq 1

      sl_1 = shp.shipment_lines[0]
      expect(sl_1.line_number).to eq 1
      expect(sl_1.quantity).to eq 5
      expect(sl_1.carton_qty).to eq 3
      expect(sl_1.product).to eq prod_1
      expect(sl_1.order_line.line_number).to eq 2
      expect(sl_1.order_line).to eq ol_1
      # Existing order lines shouldn't have been purged despite them no longer being tied to shipment line.
      expect(sl_1.order_line.order.order_lines.length).to eq 2

      expect(inbound_file).to have_identifier(:shipment_number, "MBMB20392039", Shipment, shp.id)
      expect(inbound_file).to have_info_message("Shipment 'MBMB20392039' updated.")
      expect(inbound_file).to have_no_warning_messages
    end

  end
end