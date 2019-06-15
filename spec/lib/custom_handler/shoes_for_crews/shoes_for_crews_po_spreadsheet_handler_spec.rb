describe OpenChain::CustomHandler::ShoesForCrews::ShoesForCrewsPoSpreadsheetHandler do

  def defaults overrides={}
    {
      order_id: "ORDERID",
      order_number: "ORDER#",
      order_date: Date.new(2013, 11, 14),
      ship_terms: "Ship Terms",
      order_status: "ORDER STATUS",
      ship_via: "Ship Via",
      expected_delivery_date: Date.new(2013, 11, 15),
      payment_terms: "PAYMENT Terms",
      vendor_id: "123123",
      vendor_address: "Vendor Name\r\nAddress1\r\nAddress 2",
      factory_address: "Factory Name\r\nAddress1\r\nAddress 2",
      forwarder_address: "Forwarder Name\r\nAddress1\r\nAddress 2",
      consignee_address: "Consignee Name\r\nAddress1\r\nAddress 2",
      final_dest_address: "Final Dest Name\r\nAddress1\r\nAddress 2",
      order_balance: 100.00,
      alternate_po_number: "PO#",
      items: [
        {
          item_code: "ITEMCODE1",
          warehouse_code: "ware",
          model: "Senator - Size 07, Blk",
          upc: "upc",
          unit: 1.00,
          ordered: 2.00,
          unit_cost: 3.00,
          amount: 4.00,
          case: "case",
          case_uom: "uom",
          num_cases: 5
        },
        {
          item_code: "ITEMCODE2",
          warehouse_code: "ware",
          model: "Senator - Size 07",
          upc: "upc",
          unit: 1.00,
          ordered: 2.00,
          unit_cost: 3.00,
          amount: 4.00,
          case: "case",
          case_uom: "uom",
          num_cases: 5
        },
        {
          item_code: "ITEMCODE3",
          warehouse_code: "bware",
          model: "Senator - Blk",
          upc: "upc",
          unit: 1.00,
          ordered: 2.00,
          unit_cost: 3.00,
          amount: 4.00,
          case: "case",
          case_uom: "uom",
          num_cases: 5
        },
        # There's "rollup" information interspersed in the item data container prepack data, we skip it
        {
          item_code: "\\OUTSOLE",
          model: "prepaid",
          unit: "each",
          ordered: 1.99,
          unit_cost: 2.32,
          amount: 1231.12
        }
      ]
      
    }.merge overrides
  end

  def create_workbook data
    wb = Spreadsheet::Workbook.new
    sht = wb.create_worksheet :name=>'Test'
    row = sht.row 3
    row[4] = "Order ID:"
    row[5] = data[:order_id]
    row = sht.row 4
    row[1] = "Vendor Number:"
    row[3] = data[:vendor_id]
    row[7] = "PurchaseOrderNo:"
    row[9] = data[:order_number]
    row = sht.row 5
    row[7] = "Date:"
    row[9] = data[:order_date]
    row = sht.row 6
    row[1] = "Vendor:"
    row[5] = "Factory"
    row = sht.row 7
    row[1] = data[:vendor_address]
    row[5] = data[:factory_address]
    row = sht.row 8
    row[1] = "F.O.B. Terms"
    row[4] = "Order Status"
    row[5] = "Ship Via"
    row[7] = "Expected Delivery Date"
    row[9] = "Payment Terms"
    row = sht.row 9
    row[1] = data[:ship_terms]
    row[4] = data[:order_status]
    row[5] = data[:ship_via]
    row[7] = data[:expected_delivery_date]
    row[9] = data[:payment_terms]
    row = sht.row 10
    row[1] = "Forwarder:"
    row[4] = "Consignee Notify:"
    row[8] = "Warehouse & Final Destination:"
    row = sht.row 11
    row[1] = data[:forwarder_address]
    row[4] = data[:consignee_address]
    row[8] = data[:final_dest_address]

    row = sht.row 13
    row[0] = "Item Code"
    row = sht.row 14
    row[1] = data[:alternate_po_number]
    counter = 0
    (15..(15 + (data[:items].size - 1))).each do |r|
      row = sht.row r
      i = data[:items][counter]
      row[0] = i[:item_code]
      row[2] = i[:warehouse_code]
      row[4] = i[:model]
      row[5] = i[:upc]
      row[6] = i[:unit]
      row[7] = i[:ordered]
      row[8] = i[:unit_cost]
      row[9] = i[:amount]
      row[10] = i[:case]
      row[11] = i[:case_uom]
      row[12] = i[:num_cases]

      counter += 1
    end

    row = sht.row (15 + counter + 8)
    row[8] = "Order Total:"
    row[10] = data[:order_balance]

    out = StringIO.new
    wb.write out

    out.string
  end

  let (:importer) { Factory(:importer, system_code: "SHOES") }
  before :each do
    importer
  end

  let (:log) { InboundFile.new }

  describe "parse_spreadsheet" do

    it "should parse spreadsheet data into a hash" do
      d = defaults
      s = subject.parse_spreadsheet create_workbook(d)

      expect(s[:order_id]).to eq d[:order_id]
      expect(s[:order_number]).to eq d[:order_number]
      expect(s[:order_date]).to eq d[:order_date]
      expect(s[:ship_terms]).to eq d[:ship_terms]
      expect(s[:order_status]).to eq d[:order_status]
      expect(s[:ship_via]).to eq d[:ship_via]
      expect(s[:expected_delivery_date]).to eq d[:expected_delivery_date]
      expect(s[:payment_terms]).to eq d[:payment_terms]
      expect(s[:order_balance]).to eq d[:order_balance]
      expect(s[:warehouse_code]).to eq d[:items][0][:warehouse_code]

      expect(s[:vendor][:type]).to eq "Vendor"
      expect(s[:vendor][:number]).to eq d[:vendor_id]
      expect(s[:vendor][:name]).to eq d[:vendor_address].split("\r\n")[0]
      expect(s[:vendor][:address]).to eq d[:vendor_address].split("\r\n")[1..-1].join("\n")

      expect(s[:factory][:type]).to eq "Factory"
      expect(s[:factory][:name]).to eq d[:factory_address].split("\r\n")[0]
      expect(s[:factory][:address]).to eq d[:factory_address].split("\r\n")[1..-1].join("\n")

      expect(s[:forwarder][:type]).to eq "Forwarder"
      expect(s[:forwarder][:name]).to eq d[:forwarder_address].split("\r\n")[0]
      expect(s[:forwarder][:address]).to eq d[:forwarder_address].split("\r\n")[1..-1].join("\n")

      expect(s[:consignee][:type]).to eq "Consignee"
      expect(s[:consignee][:name]).to eq d[:consignee_address].split("\r\n")[0]
      expect(s[:consignee][:address]).to eq d[:consignee_address].split("\r\n")[1..-1].join("\n")

      expect(s[:final_dest][:type]).to eq "Final Destination"
      expect(s[:final_dest][:name]).to eq d[:final_dest_address].split("\r\n")[0]
      expect(s[:final_dest][:address]).to eq d[:final_dest_address].split("\r\n")[1..-1].join("\n")

      expect(s[:items].size).to eq(3)
      s[:items].each_with_index {|i, x|
        e = d[:items][x]

        expect(i[:item_code]).to eq e[:item_code]
        expect(i[:warehouse_code]).to eq e[:warehouse_code]
        expect(i[:model]).to eq e[:model]
        expect(i[:upc]).to eq e[:upc]
        expect(i[:unit]).to eq e[:unit]
        expect(i[:ordered]).to eq e[:ordered]
        expect(i[:unit_cost]).to eq e[:unit_cost]
        expect(i[:amount]).to eq e[:amount]
        expect(i[:case]).to eq e[:case]
        expect(i[:case_uom]).to eq e[:case_uom]
        expect(i[:num_cases]).to eq e[:num_cases]
      }
    end
  end

  describe "build_xml" do

    it "should build xml" do
      s = subject.parse_spreadsheet create_workbook(defaults)
      x = subject.build_xml s

      expect(x.root.name).to eq "PurchaseOrder"
      expect(REXML::XPath.first(x, "/PurchaseOrder/OrderId").text).to eq s[:order_id]
      expect(REXML::XPath.first(x, "/PurchaseOrder/OrderNumber").text).to eq s[:order_number]
      expect(REXML::XPath.first(x, "/PurchaseOrder/OrderDate").text).to eq s[:order_date].strftime("%Y-%m-%d")
      expect(REXML::XPath.first(x, "/PurchaseOrder/FobTerms").text).to eq s[:ship_terms]
      expect(REXML::XPath.first(x, "/PurchaseOrder/OrderStatus").text).to eq s[:order_status]
      expect(REXML::XPath.first(x, "/PurchaseOrder/ShipVia").text).to eq s[:ship_via]
      expect(REXML::XPath.first(x, "/PurchaseOrder/ExpectedDeliveryDate").text).to eq s[:expected_delivery_date].strftime("%Y-%m-%d")
      expect(REXML::XPath.first(x, "/PurchaseOrder/PaymentTerms").text).to eq s[:payment_terms]
      expect(REXML::XPath.first(x, "/PurchaseOrder/OrderBalance").text).to eq s[:order_balance].to_s
      expect(REXML::XPath.first(x, "/PurchaseOrder/WarehouseCode").text).to eq s[:warehouse_code].to_s

      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Vendor']/Number").text).to eq s[:vendor][:number]
      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Vendor']/Name").text).to eq s[:vendor][:name]
      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Vendor']/Address").cdatas[0].value).to eq s[:vendor][:address]

      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Forwarder']/Name").text).to eq s[:forwarder][:name]
      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Forwarder']/Address").cdatas[0].value).to eq s[:forwarder][:address]

      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Factory']/Name").text).to eq s[:factory][:name]
      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Factory']/Address").cdatas[0].value).to eq s[:factory][:address]

      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Consignee']/Name").text).to eq s[:consignee][:name]
      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Consignee']/Address").cdatas[0].value).to eq s[:consignee][:address]

      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Final Destination']/Name").text).to eq s[:final_dest][:name]
      expect(REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Final Destination']/Address").cdatas[0].value).to eq s[:final_dest][:address]
    end
  end

  describe "write_xml" do
    it "should write xml to tempfile" do
      d = defaults
      xml = nil
      f = subject.write_xml(create_workbook(d), log) {|f| f.rewind; xml = f.read}
      # ensure the tempfile is closed
      expect(f.closed?).to be_truthy
      expect(File.basename(f)).to match(/^ShoesForCrewsPO/)
      expect(File.basename(f)).to match(/\.xml$/)

      # All the actual data is verified elsewhere, we just want to make sure the data is an xml file and validate
      # it has some data in it.
      doc = REXML::Document.new xml

      expect(REXML::XPath.first(doc, "/PurchaseOrder/OrderId").text).to eq d[:order_id]

      expect(log.company).to eq importer
    end

    it "fails if importer can't be found" do
      importer.destroy

      expect{subject.write_xml(create_workbook(defaults), log)}.to raise_error "Company with system code SHOES not found."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_ERROR)[0].message).to eq "Company with system code SHOES not found."
    end
  end

  describe "parse_file" do
    it "should call write_xml w/ ftp_file block" do
      d = defaults
      p = subject
      xml = nil
      expect(p).to receive(:ftp_file) do |f|
        f.rewind
        xml = f.read
      end

      p.parse_file create_workbook(d), log
      expect(REXML::XPath.first( REXML::Document.new(xml), "/PurchaseOrder/OrderId").text).to eq d[:order_id]
    end
  end

  describe "ftp_credentials" do
    it "should use the ftp2 server credentials" do
      p = subject
      expect(p).to receive(:ftp2_vandegrift_inc).with 'to_ecs/Shoes_For_Crews/PO'
      p.ftp_credentials
    end
  end

  describe "process_po" do
    let(:workbook_data) { defaults(@overrides) }
    let(:workbook) { create_workbook workbook_data }
    let(:data) { subject.parse_spreadsheet(create_workbook(workbook_data)) }
    let(:custom_values) {subject.instance_variable_get("@cdefs")}

    before :each do
      @overrides = {}
    end

    it "saves a new PO" do
      expect_any_instance_of(Order).to receive(:post_create_logic!)

      subject.process_po data, log, "bucket", "key"
      po = Order.where(order_number: "SHOES-ORDER#").first
      expect(po).not_to be_nil
      expect(po.importer).to eq importer
      expect(po.customer_order_number).to eq "ORDER#"
      expect(po.order_date).to eq Date.new(2013,11,14)
      expect(po.mode).to eq "Ship Via"
      expect(po.first_expected_delivery_date).to eq Date.new(2013, 11, 15)
      expect(po.terms_of_sale).to eq "PAYMENT Terms"
      expect(po.last_file_bucket).to eq "bucket"
      expect(po.last_file_path).to eq "key"
      expect(po.vendor.system_code).to eq "SHOES-123123"
      expect(po.vendor.vendor).to be_truthy
      expect(po.importer.linked_companies).to include po.vendor
      expect(po.approval_status).to eq "Accepted"
      expect(po.custom_value(custom_values[:ord_destination_codes])).to eq "bware,ware"

      expect(po.order_lines.length).to eq 3
      line = po.order_lines.first

      expect(line.line_number).to eq 1
      expect(line.product.unique_identifier).to eq "SHOES-ITEMCODE1"
      expect(line.product.name).to eq "Senator - Size 07, Blk"
      expect(line.product.unit_of_measure).to eq "uom"
      expect(line.product.importer).to eq importer
      expect(line.product.last_snapshot).not_to be_nil
      expect(line.product.custom_value(custom_values[:prod_part_number])).to eq "ITEMCODE1"

      expect(line.sku).to eq "upc"
      expect(line.quantity).to eq BigDecimal("2")
      expect(line.price_per_unit).to eq BigDecimal("3")
      expect(line.custom_value(custom_values[:ord_line_destination_code])).to eq "ware"
      expect(line.custom_value(custom_values[:ord_line_size])).to eq "07"
      expect(line.custom_value(custom_values[:ord_line_color])).to eq "Blk"

      # The next couple lines are just testing size/color parsing from the "model" source value
      line = po.order_lines[1]
      expect(line.line_number).to eq 2
      expect(line.custom_value(custom_values[:ord_line_size])).to eq "07"
      expect(line.custom_value(custom_values[:ord_line_color])).to be_nil
      expect(line.custom_value(custom_values[:ord_line_destination_code])).to eq "ware"

      line = po.order_lines[2]
      expect(line.line_number).to eq 3
      expect(line.custom_value(custom_values[:ord_line_size])).to be_nil
      expect(line.custom_value(custom_values[:ord_line_color])).to eq "Blk"
      expect(line.custom_value(custom_values[:ord_line_destination_code])).to eq "bware"

      # Verify a fingerprint was set
      fingerprint = DataCrossReference.find_po_fingerprint po
      expect(fingerprint).not_to be_nil

      expect(po.entity_snapshots.length).to eq 1
      s = po.entity_snapshots.first
      expect(s.context).to eq "key"
      expect(s.user).to eq User.integration

      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].value).to eq "ORDER#"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_type).to eq "Order"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)[0].module_id).to eq po.id
    end

    it "updates a PO" do
      order = Factory(:order, order_number: "SHOES-ORDER#", importer: importer)
      expect_any_instance_of(Order).to receive(:post_update_logic!)

      subject.process_po data, log, "bucket", "key"

      order.reload

      # Just check if there are now lines, if so, it means the order was updated
      expect(order.order_lines.length).to eq 3

      expect(order.entity_snapshots.length).to eq 1
      s = order.entity_snapshots.first
      expect(s.context).to eq "key"
      expect(s.user).to eq User.integration
    end

    it "does not update an order if the order is shipping" do
      order = Factory(:order, order_number: "SHOES-ORDER#", importer: importer)

      # mock the find_order so we can provide our own order to make sure that when an order is 
      # said to be shipping that it's not updated.
      expect(order).to receive(:shipping?).and_return true
      expect(order).not_to receive(:post_update_logic!)

      expect(subject).to receive(:find_order).and_yield true, order

      subject.process_po data, log, "bucket", "key"

      order.reload

      # Just check if there are now lines, if so, it means the order was updated
      expect(order.order_lines.length).to eq 0
    end

    it "does not update an order if the order is booked" do
      order = Factory(:order, order_number: "SHOES-ORDER#", importer: importer)

      # mock the find_order so we can provide our own order to make sure that when an order is 
      # said to be booked that it's not updated.
      expect(order).to receive(:booked?).and_return true
      expect(order).not_to receive(:post_update_logic!)

      expect(subject).to receive(:find_order).and_yield true, order

      subject.process_po data, log, "bucket", "key"

      order.reload

      # Just check if there are now lines, if so, it means the order was updated
      expect(order.order_lines.length).to eq 0
    end

    it "does not call post_update when the order has not been changed" do
      # The easiest way to ensure we get identical fingerprints is to just use the process_po method twice
      # using the same dataset.

      subject.process_po data, log, "bucket", "key"
      po = Order.where(order_number: "SHOES-ORDER#").first
      expect(subject).to receive(:find_order).and_yield true, po
      expect(po).not_to receive(:post_update_logic!)

      subject.process_po data, log, "bucket", "key2"
    end

    it "uses the alternate PO number if standard order id and order number fields are blank" do
      @overrides[:order_number] = ""
      
      subject.process_po data, log, "bucket", "key"

      po = Order.where(order_number: "SHOES-PO#").first
      expect(po).not_to be_nil
      expect(po.customer_order_number).to eq workbook_data[:alternate_po_number]
    end

    it "fails if there's no PO number provided" do
      @overrides[:order_number] = ""
      @overrides[:alternate_po_number] = ""

      expect{subject.process_po data, log, "bucket", "key"}.to raise_error "An order number must be present in all files.  File key is missing an order number."
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "An order number must be present in all files.  File key is missing an order number."
    end
  end

  describe "parse_file" do
    subject { described_class }

    it "instantiates an instance of the parser and passes through params" do
      expect_any_instance_of(subject).to receive(:parse_file).with("data", "log", "opts")

      subject.parse_file "data", "log", "opts"
    end
  end
end
