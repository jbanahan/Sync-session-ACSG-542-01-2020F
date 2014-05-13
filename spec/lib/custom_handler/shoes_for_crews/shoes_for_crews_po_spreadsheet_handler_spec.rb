require 'spec_helper'

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
      items: [
        {
          item_code: "ITEMCODE1",
          warehouse_code: "ware",
          model: "model",
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
          model: "model",
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
          warehouse_code: "ware",
          model: "model",
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

  describe "parse_spreadsheet" do

    it "should parse spreadsheet data into a hash" do
      d = defaults
      s = described_class.new.parse_spreadsheet create_workbook(d)

      s[:order_id].should eq d[:order_id]
      s[:order_number].should eq d[:order_number]
      s[:order_date].should eq d[:order_date]
      s[:ship_terms].should eq d[:ship_terms]
      s[:order_status].should eq d[:order_status]
      s[:ship_via].should eq d[:ship_via]
      s[:expected_delivery_date].should eq d[:expected_delivery_date]
      s[:payment_terms].should eq d[:payment_terms]
      s[:order_balance].should eq d[:order_balance]
      s[:warehouse_code].should eq d[:items][0][:warehouse_code]

      s[:vendor][:type].should eq "Vendor"
      s[:vendor][:number].should eq d[:vendor_id]
      s[:vendor][:name].should eq d[:vendor_address].split("\r\n")[0]
      s[:vendor][:address].should eq d[:vendor_address].split("\r\n")[1..-1].join("\n")

      s[:factory][:type].should eq "Factory"
      s[:factory][:name].should eq d[:factory_address].split("\r\n")[0]
      s[:factory][:address].should eq d[:factory_address].split("\r\n")[1..-1].join("\n")

      s[:forwarder][:type].should eq "Forwarder"
      s[:forwarder][:name].should eq d[:forwarder_address].split("\r\n")[0]
      s[:forwarder][:address].should eq d[:forwarder_address].split("\r\n")[1..-1].join("\n")

      s[:consignee][:type].should eq "Consignee"
      s[:consignee][:name].should eq d[:consignee_address].split("\r\n")[0]
      s[:consignee][:address].should eq d[:consignee_address].split("\r\n")[1..-1].join("\n")

      s[:final_dest][:type].should eq "Final Destination"
      s[:final_dest][:name].should eq d[:final_dest_address].split("\r\n")[0]
      s[:final_dest][:address].should eq d[:final_dest_address].split("\r\n")[1..-1].join("\n")

      s[:items].should have(3).items
      s[:items].each_with_index {|i, x|
        e = d[:items][x]

        i[:item_code].should eq e[:item_code]
        i[:warehouse_code].should eq e[:warehouse_code]
        i[:model].should eq e[:model]
        i[:upc].should eq e[:upc]
        i[:unit].should eq e[:unit]
        i[:ordered].should eq e[:ordered]
        i[:unit_cost].should eq e[:unit_cost]
        i[:amount].should eq e[:amount]
        i[:case].should eq e[:case]
        i[:case_uom].should eq e[:case_uom]
        i[:num_cases].should eq e[:num_cases]
      }
    end
  end

  describe "build_xml" do

    it "should build xml" do
      p = described_class.new
      s = p.parse_spreadsheet create_workbook(defaults)
      x = p.build_xml s

      x.root.name.should eq "PurchaseOrder"
      REXML::XPath.first(x, "/PurchaseOrder/OrderId").text.should eq s[:order_id]
      REXML::XPath.first(x, "/PurchaseOrder/OrderNumber").text.should eq s[:order_number]
      REXML::XPath.first(x, "/PurchaseOrder/OrderDate").text.should eq s[:order_date].strftime("%Y-%m-%d")
      REXML::XPath.first(x, "/PurchaseOrder/FobTerms").text.should eq s[:ship_terms]
      REXML::XPath.first(x, "/PurchaseOrder/OrderStatus").text.should eq s[:order_status]
      REXML::XPath.first(x, "/PurchaseOrder/ShipVia").text.should eq s[:ship_via]
      REXML::XPath.first(x, "/PurchaseOrder/ExpectedDeliveryDate").text.should eq s[:expected_delivery_date].strftime("%Y-%m-%d")
      REXML::XPath.first(x, "/PurchaseOrder/PaymentTerms").text.should eq s[:payment_terms]
      REXML::XPath.first(x, "/PurchaseOrder/OrderBalance").text.should eq s[:order_balance].to_s
      REXML::XPath.first(x, "/PurchaseOrder/WarehouseCode").text.should eq s[:warehouse_code].to_s

      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Vendor']/Number").text.should eq s[:vendor][:number]
      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Vendor']/Name").text.should eq s[:vendor][:name]
      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Vendor']/Address").cdatas[0].value.should eq s[:vendor][:address]

      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Forwarder']/Name").text.should eq s[:forwarder][:name]
      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Forwarder']/Address").cdatas[0].value.should eq s[:forwarder][:address]

      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Factory']/Name").text.should eq s[:factory][:name]
      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Factory']/Address").cdatas[0].value.should eq s[:factory][:address]

      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Consignee']/Name").text.should eq s[:consignee][:name]
      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Consignee']/Address").cdatas[0].value.should eq s[:consignee][:address]

      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Final Destination']/Name").text.should eq s[:final_dest][:name]
      REXML::XPath.first(x, "/PurchaseOrder/Party[Type = 'Final Destination']/Address").cdatas[0].value.should eq s[:final_dest][:address]
    end
  end

  describe "write_xml" do
    it "should write xml to tempfile" do
      d = defaults
      xml = nil
      f = described_class.new.write_xml(create_workbook(d)) {|f| f.rewind; xml = f.read}
      # ensure the tempfile is closed
      f.closed?.should be_true
      File.basename(f).should =~ /^ShoesForCrewsPO/
      File.basename(f).should =~ /\.xml$/

      # All the actual data is verified elsewhere, we just want to make sure the data is an xml file and validate
      # it has some data in it.
      doc = REXML::Document.new xml

      REXML::XPath.first(doc, "/PurchaseOrder/OrderId").text.should eq d[:order_id]
    end
  end

  describe "parse" do
    it "should call write_xml w/ ftp_file block" do
      d = defaults
      p = described_class.new
      xml = nil
      p.should_receive(:ftp_file) do |f|
        f.rewind
        xml = f.read
      end

      p.parse create_workbook(d)
      REXML::XPath.first( REXML::Document.new(xml), "/PurchaseOrder/OrderId").text.should eq d[:order_id]
    end
  end

  describe "ftp_credentials" do
    it "should use the ftp2 server credentials" do
      p = described_class.new
      p.should_receive(:ftp2_vandegrift_inc).with 'to_ecs/Shoes_For_Crews/PO'
      p.ftp_credentials
    end
  end
end
