require 'spec_helper'

describe OpenChain::CustomHandler::Advance::AdvancePoOriginReportParser do

  let (:file_contents) {
    # Taken from an actual file..
    [
      ["DC#", "PO No", "Warehouse#", "Warehouse Name", "Vendor ID", "Vendor Name", "Sku#", "MFG NO", "Description", "HTS#", "ORD Qty", "SHIP Qty", "Cost", "Loading Port", "Issue Date", "DC Due Date", "Lot Tracking Status", "CRD", "Load Date", "ETA DEST", "ETA DC Date", "Carrier", "B/L#", "Seal#", "Vehicle Name", "Voyage/Trip", "Container", "Container Size", "Ship Mode", "X-DOCK", "Invoice Number", "Freight Forwarder", "AP/AR NO", "bl_file_name", "TT PO"],
      ["MON", "MON4951", "89850", "Crossroads", "", "", "20671583", "YH145726", "Brake Rotor", "8708305030", 13, "", 122.85, "Shanghai, PRC", "2016-01-20", "2016-01-22", "1", "2016-01-22", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RCQ1-16011343"],
      ["MON", "MON4951", "89850", "Crossroads", "", "", "20671580", "YH145729", "Brake Rotor", "8708305030", 40, "", 458, "Shanghai, PRC", "2016-01-20", "2016-01-22", "1", "2016-01-22", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RCQ1-16011343"],
      ["IND", "IND13786", "89850", "Crossroads", "", "", "10419518", "NCV36576", "CV Axle", "8708996805", "1", "", 24.1, "Shanghai, PRC", "2016-01-21", "2016-01-22", "1", "2016-01-22", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "RCQ1-16011453"]
    ]
  }
  let (:cq) { Factory(:importer, system_code: "CQ") }
  let (:user) { Factory(:user) }
  let (:custom_file) {
    custom_file = CustomFile.new attached_file_name: "file.xlsx"
    custom_file.stub(:path).and_return "/path/to/file.xlsx"
    custom_file
  }
  subject {described_class.new custom_file }

  describe "process" do
    let (:custom_defintions) {
      subject.class.prep_custom_definitions [:prod_sku_number]
    }

    let (:product1) {
      prod = Factory(:product, importer: cq)
      prod.update_custom_value! custom_defintions[:prod_sku_number], "20671583"
      prod
    }

    let (:product2) {
      prod = Factory(:product, importer: cq)
      prod.update_custom_value! custom_defintions[:prod_sku_number], "20671580"
      prod
    }

    let (:product3) {
      prod = Factory(:product, importer: cq)
      prod.update_custom_value! custom_defintions[:prod_sku_number], "10419518"
      prod
    }

    context "with all products present" do
      before :each do
        product1
        product2
        product3

        Product.any_instance.stub(:can_view?).and_return true
      end

      it "processes a file, saves orders and products" do
        subject.should_receive(:foreach).with(custom_file).and_yield(file_contents[0], 0).and_yield(file_contents[1], 1).and_yield(file_contents[2], 2).and_yield(file_contents[3], 3)
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

        line = order.order_lines.second
        expect(line.sku).to eq "20671580"
        expect(line.hts).to eq "8708305030"
        expect(line.quantity).to eq 40
        expect(line.product).to eq product2

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
      end
    end

    context "missing product 2" do
      before :each do
        product1
        product3

        Product.any_instance.stub(:can_view?).and_return true
      end

      it "generates a product file and PO file containing data for the missing part" do
        subject.should_receive(:foreach).with(custom_file).and_yield(file_contents[0], 0).and_yield(file_contents[1], 1).and_yield(file_contents[2], 2).and_yield(file_contents[3], 3)
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
        expect(mail.body.raw_source).to include "Attached are the product lines that were missing from VFI Track.  Please fill out the file - Missing Products.xls file with all the necessary information and load the data into VFI Track, then reprocess the attached file - Orders.xls PO file to load the POs that were missing products into the system."
        expect(mail.attachments["file - Missing Products.xls"]).not_to be_nil
        expect(mail.attachments["file - Orders.xls"]).not_to be_nil

        # Make sure the missing products file is as expected (just make sure the sku number got placed correctly)
        wb = Spreadsheet.open(StringIO.new(mail.attachments["file - Missing Products.xls"].read))
        sheet = wb.worksheet 0
        expect(sheet.row(1)[0]).to eq "20671580"

        wb = Spreadsheet.open(StringIO.new(mail.attachments["file - Orders.xls"].read))
        sheet = wb.worksheet 0
        # Don't care how many trailing blank columns there are
        expect(sheet.row(1).to_a[0..34]).to eq file_contents[1].map {|v| v.blank? ? nil : v}[0..34]
        expect(sheet.row(2).to_a[0..34]).to eq file_contents[2].map {|v| v.blank? ? nil : v}[0..34]

        # Make sure the second row is highlighted because the product was missing
        expect(sheet.row(2).formats[0].pattern_fg_color).to eq :yellow
        expect(sheet.row(2).formats[0].pattern).to eq 1

        expect(sheet.row(3)).to be_blank
      end

      it "adds only a single line to product file, even when product is missing multiple times" do
        # Just yield the same line multiple times, and we should only see the part on the product file once
        subject.should_receive(:foreach).with(custom_file).and_yield(file_contents[0], 0).and_yield(file_contents[2], 2).and_yield(file_contents[2], 2)
        subject.process user

        mail = ActionMailer::Base.deliveries.first
        expect(mail.attachments["file - Missing Products.xls"]).not_to be_nil

        # Make sure the missing products file is as expected (just make sure the sku number got placed correctly)
        wb = Spreadsheet.open(StringIO.new(mail.attachments["file - Missing Products.xls"].read))
        sheet = wb.worksheet 0
        expect(sheet.row(1)[0]).to eq "20671580"
        expect(sheet.row(2)).to be_blank
      end
    end
  end

  describe "can_view?" do
    let (:ms) { double("MasterSetup") }
    let (:user) { Factory(:master_user) }

    context "with alliance enabled master_setup" do
      before :each do
        MasterSetup.stub(:get).and_return ms
        ms.stub(:custom_feature?).with("alliance").and_return true
      end

      it "allows user" do
        user.should_receive(:edit_orders?).and_return true
        expect(described_class.can_view? user).to be_true
      end

      it "disallows users that can't edit products" do
        user.should_receive(:edit_orders?).and_return false
        expect(described_class.can_view? user).to be_false
      end

      it "disallows users that aren't master users" do
        user = Factory(:user)
        user.stub(:edit_orders?).and_return true
        expect(described_class.can_view? user).to be_false
      end
    end

    it "disallows when alliance is not enabled" do
      MasterSetup.should_receive(:get).and_return ms
      ms.stub(:custom_feature?).with("alliance").and_return false

      user.stub(:edit_orders?).and_return true
      expect(described_class.can_view? user).to be_false
    end
  end

  describe "valid_file?" do
    let (:xlsx_file) { custom_file }
    let (:xls_file) {
      custom_file = CustomFile.new attached_file_name: "file.xls"
      custom_file.stub(:path).and_return "/path/to/file.xls"
      custom_file
    }

    it "allows xlsx files" do
      expect(described_class.new(xlsx_file).valid_file?).to be_true
    end

    it "allows xls files" do
      expect(described_class.new(xls_file).valid_file?).to be_true
    end

    it "disallows other files" do
      custom_file = CustomFile.new attached_file_name: "file.txt"
      custom_file.stub(:path).and_return "/path/to/file.txt"

      expect(described_class.new(custom_file).valid_file?).to be_false
    end
  end
end