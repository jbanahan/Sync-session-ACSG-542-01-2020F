require 'spec_helper'

describe OpenChain::CustomHandler::Advance::AdvancePoOriginReportParser do

  let (:file_contents) {
    # Taken from an actual file..
    [
      ["DC#", "PO No", "Warehouse#", "Warehouse Name", "Vendor ID", "Vendor Name", "Sku#", "MFG NO", "Description", "HTS#", "ORD Qty", "SHIP Qty", "Cost", "Loading Port", "Issue Date", "DC Due Date", "Lot Tracking Status", "CRD", "Load Date", "ETA DEST", "ETA DC Date", "Carrier", "B/L#", "Seal#", "Vehicle Name", "Voyage/Trip", "Container", "Container Size", "Ship Mode", "X-DOCK", "Invoice Number", "Freight Forwarder", "AP/AR NO", "bl_file_name", "TT PO", "COO", "FULL CQ SKU"],
      ["MON", "MON4951", "89850", "Crossroads", "", "", "20671583", "YH145726", "Brake Rotor", "8708305030", 13, "", 122.85, "Shanghai, PRC", "2016-01-20", "2016-01-22", "1", "2016-01-22", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RCQ1-16011343", "CN", "PART1"],
      ["MON", "MON4951", "89850", "Crossroads", "", "", "20671580", "YH145729", "Brake Rotor", "8708305030", 40, "", 458, "Shanghai, PRC", "2016-01-20", "2016-01-22", "1", "2016-01-22", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RCQ1-16011343", "CN", "PART2"],
      ["IND", "IND13786", "89850", "Crossroads", "", "", "10419518", "NCV36576", "CV Axle", "8708996805", "1", "", 24.1, "Shanghai, PRC", "2016-01-21", "2016-01-22", "1", "2016-01-22", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RCQ1-16011453", "CN", "PART3"]
    ]
  }
  let (:cq) { Factory(:importer, system_code: "CQ") }
  let (:user) { Factory(:user) }
  let (:custom_file) {
    custom_file = CustomFile.new attached_file_name: "file.xlsx"
    allow(custom_file).to receive(:path).and_return "/path/to/file.xlsx"
    custom_file
  }
  subject {described_class.new custom_file }

  describe "process" do
    let (:custom_defintions) {
      subject.class.prep_custom_definitions [:prod_sku_number]
    }

    let (:product1) {
      prod = Factory(:product, importer: cq, unique_identifier: "CQ-PART1")
      prod.update_custom_value! custom_defintions[:prod_sku_number], "20671583"
      prod
    }

    let (:product2) {
      prod = Factory(:product, importer: cq, unique_identifier: "CQ-PART2")
      prod.update_custom_value! custom_defintions[:prod_sku_number], "20671580"
      prod
    }

    let (:product3) {
      prod = Factory(:product, importer: cq, unique_identifier: "CQ-PART3")
      prod.update_custom_value! custom_defintions[:prod_sku_number], "10419518"
      prod
    }

    context "with all products present" do
      before :each do
        product1
        product2
        product3

        allow_any_instance_of(Product).to receive(:can_view?).and_return true
      end

      it "processes a file, saves orders and products" do
        expect(subject).to receive(:foreach).with(custom_file).and_yield(file_contents[0], 0).and_yield(file_contents[1], 1).and_yield(file_contents[2], 2).and_yield(file_contents[3], 3)
        subject.process user 

        expect(user.messages.length).to eq 1
        m = user.messages.first
        expect(m.subject).to eq "CQ Origin Report Complete"
        expect(m.body).to eq "The report has been processed without error."

        order = Order.where(order_number: "CQ-MON4951").first
        expect(order).not_to be_nil
        expect(order.customer_order_number).to eq "MON4951"
        expect(order.order_date).to eq Date.new(2016, 1, 20)
        expect(order.importer).to eq cq
        expect(order.order_lines.length).to eq 2

        line = order.order_lines.first
        expect(line.sku).to eq "20671583"
        expect(line.hts).to eq "8708305030"
        expect(line.quantity).to eq 13
        expect(line.product).to eq product1
        expect(line.price_per_unit).to eq BigDecimal("9.45")
        expect(line.country_of_origin).to eq "CN"

        line = order.order_lines.second
        expect(line.sku).to eq "20671580"
        expect(line.hts).to eq "8708305030"
        expect(line.quantity).to eq 40
        expect(line.product).to eq product2
        expect(line.price_per_unit).to eq BigDecimal("11.45")
        expect(line.country_of_origin).to eq "CN"

        order = Order.where(order_number: "CQ-IND13786").first
        expect(order).not_to be_nil
        expect(order.customer_order_number).to eq "IND13786"
        expect(order.order_date).to eq Date.new(2016, 1, 21)
        expect(order.importer).to eq cq
        expect(order.order_lines.length).to eq 1

        line = order.order_lines.first
        expect(line.sku).to eq "10419518"
        expect(line.hts).to eq "8708996805"
        expect(line.quantity).to eq 1
        expect(line.product).to eq product3
        expect(line.price_per_unit).to eq BigDecimal("24.10")
        expect(line.country_of_origin).to eq "CN"
      end
    end

    context "missing product 2" do
      before :each do
        product1
        product3

        allow_any_instance_of(Product).to receive(:can_view?).and_return true
      end

      it "generates a product file and PO file containing data for the missing part" do
        expect(subject).to receive(:foreach).with(custom_file).and_yield(file_contents[0], 0).and_yield(file_contents[1], 1).and_yield(file_contents[2], 2).and_yield(file_contents[3], 3)
        subject.process user

        expect(user.messages.length).to eq 1
        m = user.messages.first
        expect(m.subject).to eq "CQ Origin Report Complete With Errors"
        expect(m.body).to eq "The report has been processed, however, 1 product was missing from VFI Track.<br>A separate email containing order and product files has been emailed to you. Follow the instructions in the email to complete the data load."

        order = Order.where(order_number: "CQ-MON4951").first
        expect(order).not_to be_nil
        expect(order.order_lines.length).to eq 1
        expect(order.order_lines.first.product).to eq product1

        order = Order.where(order_number: "CQ-IND13786").first
        expect(order).not_to be_nil
        expect(order.order_lines.length).to eq 1
        expect(order.order_lines.first.product).to eq product3

        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eq [user.email]
        expect(mail.subject).to eq "CQ Origin PO Report Result"
        expect(mail.body.raw_source).to include "Attached are the product lines that were missing from VFI Track.  Please fill out the file - Missing Products.xlsx file with all the necessary information and load the data into VFI Track, then reprocess the attached file - Orders.xlsx PO file to load the POs that were missing products into the system."
        expect(mail.attachments["file - Missing Products.xlsx"]).not_to be_nil
        expect(mail.attachments["file - Orders.xlsx"]).not_to be_nil

        # Make sure the missing products file is as expected (just make sure the sku number got placed correctly)
        reader = XlsxTestReader.new StringIO.new(mail.attachments["file - Missing Products.xlsx"].read)
        sheet = reader.sheet "Missing Products"
        expect(reader.raw_data(sheet)[1]).to eq ["20671580", nil, nil, "PART2"]


        reader = XlsxTestReader.new StringIO.new(mail.attachments["file - Orders.xlsx"].read)
        sheet = reader.sheet "Orders Missing Products"
        data = reader.raw_data(sheet)
        expect(data[1]).to eq file_contents[1][0..36]
        expect(data[2]).to eq file_contents[2][0..36]
        # Make sure the second row is highlighted because the product was missing
        expect(reader.background_color(sheet, 2, 1)).to eq "FFFFFF00"
      end

      it "adds only a single line to product file, even when product is missing multiple times" do
        # Just yield the same line multiple times, and we should only see the part on the product file once
        expect(subject).to receive(:foreach).with(custom_file).and_yield(file_contents[0], 0).and_yield(file_contents[2], 2).and_yield(file_contents[2], 2)
        subject.process user

        mail = ActionMailer::Base.deliveries.first
        expect(mail.attachments["file - Missing Products.xlsx"]).not_to be_nil

        # Make sure the missing products file is as expected (just make sure the sku number got placed correctly)
        reader = XlsxTestReader.new StringIO.new(mail.attachments["file - Missing Products.xlsx"].read)
        sheet = reader.sheet "Missing Products"
        data = reader.raw_data(sheet)
        expect(data[1][0]).to eq "20671580"
        expect(data[2]).to be_nil
      end
    end
  end

  describe "can_view?" do
    let (:ms) { double("MasterSetup") }
    let (:user) { Factory(:master_user) }

    context "with alliance enabled master_setup" do
      before :each do
        allow(MasterSetup).to receive(:get).and_return ms
        allow(ms).to receive(:custom_feature?).with("alliance").and_return true
      end

      it "allows user" do
        expect(user).to receive(:edit_orders?).and_return true
        expect(described_class.can_view? user).to be_truthy
      end

      it "disallows users that can't edit products" do
        expect(user).to receive(:edit_orders?).and_return false
        expect(described_class.can_view? user).to be_falsey
      end

      it "disallows users that aren't master users" do
        user = Factory(:user)
        allow(user).to receive(:edit_orders?).and_return true
        expect(described_class.can_view? user).to be_falsey
      end
    end

    it "disallows when alliance is not enabled" do
      expect(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("alliance").and_return false

      allow(user).to receive(:edit_orders?).and_return true
      expect(described_class.can_view? user).to be_falsey
    end
  end

  describe "valid_file?" do
    let (:xlsx_file) { custom_file }
    let (:xls_file) {
      custom_file = CustomFile.new attached_file_name: "file.xls"
      allow(custom_file).to receive(:path).and_return "/path/to/file.xls"
      custom_file
    }

    it "allows xlsx files" do
      expect(described_class.new(xlsx_file).valid_file?).to be_truthy
    end

    it "allows xls files" do
      expect(described_class.new(xls_file).valid_file?).to be_truthy
    end

    it "disallows other files" do
      custom_file = CustomFile.new attached_file_name: "file.txt"
      allow(custom_file).to receive(:path).and_return "/path/to/file.txt"

      expect(described_class.new(custom_file).valid_file?).to be_falsey
    end
  end
end
